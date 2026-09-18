/// User profile, a Dart mirror of the `users/{uid}` Firestore document.
///
/// Keep this model free of UI logic — only parsing + convenience getters.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.bio = '',
    this.isPrivate = false,
    this.isVerified = false,
    this.mfaEnabled = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  });

  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final String bio;
  final bool isPrivate;
  final bool isVerified;
  final bool mfaEnabled;
  final int followersCount;
  final int followingCount;
  final int postsCount;

  /// Builds an [AppUser] from a Firestore document map. Null-safe on every field.
  factory AppUser.fromMap(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String? ?? '',
      isPrivate: json['isPrivate'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      mfaEnabled: json['mfaEnabled'] as bool? ?? false,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serializes to a map suitable for `set(..., merge: true)`.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'bio': bio,
      'isPrivate': isPrivate,
      'isVerified': isVerified,
      'mfaEnabled': mfaEnabled,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
    };
  }
}
