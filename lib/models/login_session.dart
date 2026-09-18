import 'package:cloud_firestore/cloud_firestore.dart';

/// One login session / device, mirrors `users/{uid}/sessions/{sessionId}`.
class LoginSession {
  const LoginSession({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.signInMethod,
    required this.createdAt,
    required this.lastActiveAt,
    this.isCurrent = false,
  });

  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String osVersion;
  final String appVersion;
  final String signInMethod;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isCurrent;

  factory LoginSession.fromMap(Map<String, dynamic> json) {
    return LoginSession(
      sessionId: json['sessionId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Thiết bị không xác định',
      platform: json['platform'] as String? ?? '',
      osVersion: json['osVersion'] as String? ?? '',
      appVersion: json['appVersion'] as String? ?? '',
      signInMethod: json['signInMethod'] as String? ?? '',
      createdAt: _toDate(json['createdAt']),
      lastActiveAt: _toDate(json['lastActiveAt']),
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'sessionId': sessionId,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'osVersion': osVersion,
    'appVersion': appVersion,
    'signInMethod': signInMethod,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    'isCurrent': isCurrent,
  };

  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
