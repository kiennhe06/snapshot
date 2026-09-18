import 'package:firebase_auth/firebase_auth.dart';

import 'package:snapshot/core/i18n/i18n.dart';

/// Maps a [FirebaseAuthException] to a friendly, localized message.
///
/// Never surface a raw Firebase error code/message to the user.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => tr('Email không hợp lệ.', 'Invalid email.'),
      'user-disabled' => tr(
        'Tài khoản đã bị vô hiệu hoá.',
        'This account has been disabled.',
      ),
      'user-not-found' => tr('Không tìm thấy tài khoản.', 'Account not found.'),
      'wrong-password' || 'invalid-credential' => tr(
        'Sai email hoặc mật khẩu.',
        'Wrong email or password.',
      ),
      'email-already-in-use' => tr(
        'Email đã được đăng ký.',
        'This email is already registered.',
      ),
      'weak-password' => tr(
        'Mật khẩu quá yếu (tối thiểu 6 ký tự).',
        'Password is too weak (at least 6 characters).',
      ),
      'network-request-failed' => tr(
        'Lỗi mạng. Vui lòng kiểm tra kết nối.',
        'Network error. Please check your connection.',
      ),
      'too-many-requests' => tr(
        'Bạn thử quá nhiều lần, vui lòng đợi một lát.',
        'Too many attempts, please wait a moment.',
      ),
      'operation-not-allowed' => tr(
        'Phương thức đăng nhập chưa được bật trong Firebase.',
        'This sign-in method is not enabled in Firebase.',
      ),
      'invalid-verification-code' => tr(
        'Mã OTP không đúng.',
        'Incorrect OTP code.',
      ),
      'invalid-verification-id' => tr(
        'Phiên xác thực hết hạn, vui lòng thử lại.',
        'The verification session has expired, please try again.',
      ),
      'invalid-phone-number' => tr(
        'Số điện thoại không hợp lệ.',
        'Invalid phone number.',
      ),
      'missing-id-token' => tr(
        'Thiếu idToken. Kiểm tra bật Google Sign-In và SHA-1.',
        'Missing idToken. Check that Google Sign-In and SHA-1 are enabled.',
      ),
      'requires-recent-login' => tr(
        'Thao tác này cần bạn đăng nhập lại gần đây.',
        'This action requires you to have signed in recently.',
      ),
      _ =>
        error.message ??
            tr(
              'Đã xảy ra lỗi, vui lòng thử lại.',
              'Something went wrong, please try again.',
            ),
    };
  }
  return tr(
    'Đã xảy ra lỗi, vui lòng thử lại.',
    'Something went wrong, please try again.',
  );
}
