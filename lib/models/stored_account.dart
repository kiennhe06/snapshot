/// Lightweight metadata of a previously signed-in account, persisted locally so
/// the user can quickly switch between multiple accounts.
///
/// NOTE: we never store passwords or tokens here — only display metadata.
/// Switching to an account that is not the current Firebase user requires
/// re-authentication (see AccountStore / auth flow).
class StoredAccount {
  const StoredAccount({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.signInMethod,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// One of: `password`, `google.com`, `phone`.
  final String signInMethod;

  factory StoredAccount.fromMap(Map<String, dynamic> json) {
    return StoredAccount(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      signInMethod: json['signInMethod'] as String? ?? 'password',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'signInMethod': signInMethod,
  };

  StoredAccount copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
  }) {
    return StoredAccount(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      signInMethod: signInMethod,
    );
  }
}
