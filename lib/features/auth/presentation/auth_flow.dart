import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/stored_account.dart';
import '../providers/auth_providers.dart';

/// Shared post-sign-in side effects: ensure the profile doc exists, record the
/// device session (login history), and remember the account for quick
/// switching. Called by every sign-in path.
Future<void> handlePostSignIn(
  WidgetRef ref, {
  required User user,
  required String signInMethod,
}) async {
  // Capture providers BEFORE any await: a successful sign-in flips the auth
  // state and the router disposes the calling screen mid-flight, which would
  // otherwise make a post-await ref.read throw "used after dispose".
  final sessionService = ref.read(sessionServiceProvider);
  final accounts = ref.read(accountsProvider.notifier);

  // Ensure a minimal users/{uid} profile document (merge = safe if it exists).
  // createdAt is only set on first write via a separate get-check.
  await _ensureUserDoc(user);

  // Login history / device record (non-fatal on failure).
  await sessionService.recordLogin(uid: user.uid, signInMethod: signInMethod);

  // Remember account locally for the multi-account switcher.
  await accounts.remember(
        StoredAccount(
          uid: user.uid,
          displayName:
              user.displayName ??
              user.email ??
              user.phoneNumber ??
              'Người dùng',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          signInMethod: signInMethod,
        ),
      );
}

/// Creates the users/{uid} document on first sign-in; merges basic fields
/// afterwards. Wrapped so a Firestore failure never blocks sign-in.
Future<void> _ensureUserDoc(User user) async {
  try {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    final base = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'phoneNumber': user.phoneNumber,
      'displayName':
          user.displayName ?? user.email?.split('@').first ?? 'Người dùng',
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      base['createdAt'] = FieldValue.serverTimestamp();
      base['username'] = '';
      base['bio'] = '';
      base['isPrivate'] = false;
      base['isVerified'] = false;
      base['mfaEnabled'] = false;
      base['followersCount'] = 0;
      base['followingCount'] = 0;
      base['postsCount'] = 0;
    }
    await ref.set(base, SetOptions(merge: true));
  } catch (_) {
    // Non-fatal: profile doc can be repaired later.
  }
}
