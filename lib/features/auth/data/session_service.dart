import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../models/login_session.dart';

/// Records login history / devices under `users/{uid}/sessions/{sessionId}`.
///
/// Every Firestore write is wrapped in try/catch: an infrastructure error must
/// never break the main sign-in flow.
class SessionService {
  SessionService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _deviceIdKey = 'stable_device_id_v1';

  CollectionReference<Map<String, dynamic>> _sessions(String uid) =>
      _db.collection('users').doc(uid).collection('sessions');

  /// Creates (or refreshes) a session document for the current device after a
  /// successful sign-in. Returns silently on any failure.
  Future<void> recordLogin({
    required String uid,
    required String signInMethod,
  }) async {
    try {
      final info = await _collectDeviceInfo();
      final now = DateTime.now();
      final session = LoginSession(
        sessionId: info.deviceId, // one session doc per physical device
        deviceId: info.deviceId,
        deviceName: info.deviceName,
        platform: info.platform,
        osVersion: info.osVersion,
        appVersion: info.appVersion,
        signInMethod: signInMethod,
        createdAt: now,
        lastActiveAt: now,
        isCurrent: true,
      );
      await _sessions(uid).doc(info.deviceId).set(session.toMap());
    } catch (_) {
      // Non-fatal: skip login history if the write fails.
    }
  }

  /// Streams the user's sessions, newest activity first.
  Stream<List<LoginSession>> watchSessions(String uid) {
    return _sessions(uid)
        .orderBy('lastActiveAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => LoginSession.fromMap(d.data())).toList(),
        );
  }

  /// Revokes (removes) a remote session document. Note: this deletes the record
  /// only; actually forcing sign-out on that device needs a Cloud Function that
  /// revokes refresh tokens (a later phase).
  Future<void> revokeSession(String uid, String sessionId) async {
    try {
      await _sessions(uid).doc(sessionId).delete();
    } catch (_) {
      rethrow;
    }
  }

  Future<_DeviceInfo> _collectDeviceInfo() async {
    final deviceId = await _stableDeviceId();
    final pkg = await PackageInfo.fromPlatform();
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      return _DeviceInfo(
        deviceId: deviceId,
        deviceName: '${a.manufacturer} ${a.model}',
        platform: 'android',
        osVersion: 'Android ${a.version.release}',
        appVersion: '${pkg.version}+${pkg.buildNumber}',
      );
    }
    final i = await plugin.iosInfo;
    return _DeviceInfo(
      deviceId: deviceId,
      deviceName: i.name,
      platform: 'ios',
      osVersion: '${i.systemName} ${i.systemVersion}',
      appVersion: '${pkg.version}+${pkg.buildNumber}',
    );
  }

  /// A stable per-install id (device identifiers are not reliable/allowed), so
  /// we generate one once and keep it in SharedPreferences.
  Future<String> _stableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}

class _DeviceInfo {
  const _DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String osVersion;
  final String appVersion;
}
