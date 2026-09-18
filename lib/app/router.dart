import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/mfa/mfa_challenge_screen.dart';
import '../features/auth/presentation/mfa/mfa_enroll_screen.dart';
import '../features/auth/presentation/phone_sign_in_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/interactions/presentation/hidden_words_screen.dart';
import '../features/interactions/presentation/saved_screen.dart';
import '../features/post/presentation/create_post_screen.dart';
import '../features/post/presentation/drafts_screen.dart';
import '../features/post/presentation/edit_post_screen.dart';
import '../models/post.dart';
import '../models/post_draft.dart';
import '../features/profile/presentation/archive_screen.dart';
import '../features/profile/presentation/change_password_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/qr_nametag_screen.dart';
import '../features/settings/presentation/login_history_screen.dart';

/// Routes reachable while signed out (part of the sign-in flow).
const _publicRoutes = <String>{
  Routes.signIn,
  Routes.signUp,
  Routes.forgotPassword,
  Routes.phoneSignIn,
  Routes.mfaChallenge,
};

/// GoRouter wired to [authStateProvider]; it rebuilds on login/logout and
/// redirects accordingly.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Auth state not resolved yet -> stay on splash.
      if (authState.isLoading) {
        return loc == Routes.splash ? null : Routes.splash;
      }

      final signedIn = authState.valueOrNull != null;

      if (!signedIn) {
        // Allow the sign-in flow routes; send everything else to sign-in.
        return _publicRoutes.contains(loc) ? null : Routes.signIn;
      }

      // Signed in: keep them out of splash / public auth screens.
      if (loc == Routes.splash || _publicRoutes.contains(loc)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.phoneSignIn,
        builder: (_, _) => const PhoneSignInScreen(),
      ),
      GoRoute(
        path: Routes.mfaChallenge,
        builder: (_, state) =>
            MfaChallengeScreen(resolver: state.extra as MultiFactorResolver),
      ),
      GoRoute(
        path: Routes.mfaEnroll,
        builder: (_, _) => const MfaEnrollScreen(),
      ),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeShell()),
      GoRoute(
        path: Routes.loginHistory,
        builder: (_, _) => const LoginHistoryScreen(),
      ),
      // Phase 2 — Profile
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '${Routes.userProfile}/:uid',
        builder: (_, state) => ProfileScreen(uid: state.pathParameters['uid']),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: Routes.qrNametag,
        builder: (_, state) =>
            QrNametagScreen(uid: state.uri.queryParameters['uid'] ?? ''),
      ),
      GoRoute(
        path: Routes.createPost,
        builder: (_, state) =>
            CreatePostScreen(draft: state.extra as PostDraft?),
      ),
      GoRoute(
        path: Routes.editPost,
        builder: (_, state) => EditPostScreen(post: state.extra as Post),
      ),
      GoRoute(path: Routes.drafts, builder: (_, _) => const DraftsScreen()),
      GoRoute(path: Routes.archive, builder: (_, _) => const ArchiveScreen()),
      GoRoute(path: Routes.saved, builder: (_, _) => const SavedScreen()),
      GoRoute(
        path: Routes.hiddenWords,
        builder: (_, _) => const HiddenWordsScreen(),
      ),
    ],
  );
});
