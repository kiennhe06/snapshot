import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants.dart';

/// Result of starting a phone verification. Carries the [verificationId] needed
/// to build the SMS credential once the user types the OTP.
class PhoneVerification {
  const PhoneVerification({required this.verificationId, this.resendToken});
  final String verificationId;
  final int? resendToken;
}

/// Thin wrapper around FirebaseAuth. All auth I/O lives here; widgets talk to it
/// only through providers. Errors bubble up as FirebaseAuthException and are
/// mapped to Vietnamese by [authErrorMessage] at the UI layer.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleInitialized = false;

  /// Emits the current user (or null) whenever auth state changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In (google_sign_in v7: singleton + initialize + authenticate)
  // ---------------------------------------------------------------------------

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    // serverClientId MUST be the Web client id so idToken audience matches
    // Firebase on both Android and iOS.
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const <String>['email', 'profile'],
    );
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Kiểm tra đã bật Google Sign-In và thêm SHA-1.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Phone / OTP
  // ---------------------------------------------------------------------------

  /// Starts phone verification. On Android an SMS may be auto-retrieved, in
  /// which case [onAutoVerified] signs the user in directly.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(PhoneVerification verification) onCodeSent,
    required void Function(Object error) onFailed,
    void Function(UserCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (onAutoVerified == null) return;
        try {
          final result = await _auth.signInWithCredential(credential);
          onAutoVerified(result);
        } catch (e) {
          onFailed(e);
        }
      },
      verificationFailed: onFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(
          PhoneVerification(
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Completes phone sign-in with the SMS code the user typed.
  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Two-factor (MFA) — requires Google Cloud Identity Platform (Blaze plan)
  // ---------------------------------------------------------------------------

  /// Enrolls the current user into SMS-based 2FA.
  /// Step 1: send an OTP to [phoneNumber] using an MFA session.
  Future<PhoneVerification> startMfaEnrollment({
    required String phoneNumber,
    required void Function(Object error) onFailed,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Bạn cần đăng nhập trước khi bật 2FA.',
      );
    }
    final session = await user.multiFactor.getSession();
    final completer = Completer<PhoneVerification>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      multiFactorSession: session,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
        onFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerification(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// Step 2: confirm the OTP and finish enrolling the second factor.
  Future<void> confirmMfaEnrollment({
    required String verificationId,
    required String smsCode,
    String displayName = 'Số điện thoại',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  /// During sign-in, Firebase throws [FirebaseAuthMultiFactorException] when a
  /// second factor is required. Send an OTP to the enrolled phone hint.
  Future<PhoneVerification> startMfaChallenge({
    required MultiFactorResolver resolver,
    required void Function(Object error) onFailed,
  }) async {
    final hint = resolver.hints.first;
    final completer = Completer<PhoneVerification>();
    await _auth.verifyPhoneNumber(
      multiFactorSession: resolver.session,
      multiFactorInfo: hint is PhoneMultiFactorInfo ? hint : null,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
        onFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerification(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// Finish the MFA challenge and sign the user in.
  Future<UserCredential> confirmMfaChallenge({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    return resolver.resolveSignIn(assertion);
  }

  Future<List<MultiFactorInfo>> enrolledFactors() async {
    final user = _auth.currentUser;
    if (user == null) return const [];
    return user.multiFactor.getEnrolledFactors();
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore: user may not have signed in with Google.
    }
    await _auth.signOut();
  }
}
