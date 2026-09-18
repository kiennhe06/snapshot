/// App-wide constants and configuration keys.
class AppConfig {
  const AppConfig._();

  /// OAuth *Web* client id (oauth_client type 3) taken from google-services.json.
  /// REQUIRED so Google Sign-In returns an idToken with the correct audience
  /// for Firebase on BOTH Android and iOS. Fill after `flutterfire configure`.
  static const String googleWebClientId =
      '430324568256-n3e10gqml1j8tecnb6fal1daqg834qfj.apps.googleusercontent.com';
}

/// Keys used with SharedPreferences.
class PrefsKeys {
  const PrefsKeys._();

  static const String storedAccounts = 'stored_accounts_v1';
  static const String activeAccountUid = 'active_account_uid_v1';
  static const String themeMode = 'theme_mode_v1';
}

/// Centralized route paths (kept in one place, used by GoRouter).
class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String phoneSignIn = '/phone-sign-in';
  static const String mfaChallenge = '/mfa-challenge';
  static const String mfaEnroll = '/mfa-enroll';
  static const String home = '/';
  static const String loginHistory = '/settings/login-history';

  // Phase 2 — Profile
  static const String profile = '/profile'; // own profile
  static const String userProfile = '/user'; // /user/:uid
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String qrNametag = '/qr-nametag';
  static const String createPost = '/create-post';
  static const String archive = '/archive';
}
