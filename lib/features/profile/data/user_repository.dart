import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/app_user.dart';

/// Reads/writes user profiles and enforces username uniqueness.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Streams a user profile document.
  Stream<AppUser?> watchUser(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : AppUser.fromMap(data);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    return data == null ? null : AppUser.fromMap(data);
  }

  /// Updates simple profile fields (name, bio, website, avatar).
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? website,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (displayName != null) data['displayName'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (website != null) data['website'] = website;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    await _userDoc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> setPrivate(String uid, bool isPrivate) {
    return _userDoc(uid).set({
      'isPrivate': isPrivate,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Whether [username] is free (or already owned by [uid]).
  Future<bool> isUsernameAvailable(
    String username, {
    required String uid,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final doc = await _db.collection('usernames').doc(normalized).get();
    if (!doc.exists) return true;
    return doc.data()?['uid'] == uid;
  }

  /// Atomically changes a username: reserves the new one, frees the old one,
  /// and updates the profile. Throws if the name is already taken.
  Future<void> changeUsername({
    required String uid,
    required String newUsername,
    String? oldUsername,
  }) async {
    final normalized = newUsername.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('Username không được để trống.');
    }
    await _db.runTransaction((tx) async {
      final newRef = _db.collection('usernames').doc(normalized);
      final newSnap = await tx.get(newRef);
      if (newSnap.exists && newSnap.data()?['uid'] != uid) {
        throw StateError('Username đã có người dùng.');
      }
      tx.set(newRef, {'uid': uid});
      if (oldUsername != null &&
          oldUsername.isNotEmpty &&
          oldUsername.toLowerCase() != normalized) {
        tx.delete(_db.collection('usernames').doc(oldUsername.toLowerCase()));
      }
      tx.set(_userDoc(uid), {
        'username': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Re-authenticates with the current password, then sets a new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Không tìm thấy tài khoản.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
