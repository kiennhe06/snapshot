import 'package:firebase_auth/firebase_auth.dart';

/// Maps a [FirebaseAuthException] to a friendly Vietnamese message.
///
/// Never surface a raw Firebase error code/message to the user.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Email không hợp lệ.',
      'user-disabled' => 'Tài khoản đã bị vô hiệu hoá.',
      'user-not-found' => 'Không tìm thấy tài khoản.',
      'wrong-password' || 'invalid-credential' => 'Sai email hoặc mật khẩu.',
      'email-already-in-use' => 'Email đã được đăng ký.',
      'weak-password' => 'Mật khẩu quá yếu (tối thiểu 6 ký tự).',
      'network-request-failed' => 'Lỗi mạng. Vui lòng kiểm tra kết nối.',
      'too-many-requests' => 'Bạn thử quá nhiều lần, vui lòng đợi một lát.',
      'operation-not-allowed' =>
        'Phương thức đăng nhập chưa được bật trong Firebase.',
      'invalid-verification-code' => 'Mã OTP không đúng.',
      'invalid-verification-id' => 'Phiên xác thực hết hạn, vui lòng thử lại.',
      'invalid-phone-number' => 'Số điện thoại không hợp lệ.',
      'missing-id-token' =>
        'Thiếu idToken. Kiểm tra bật Google Sign-In và SHA-1.',
      'requires-recent-login' => 'Thao tác này cần bạn đăng nhập lại gần đây.',
      _ => error.message ?? 'Đã xảy ra lỗi, vui lòng thử lại.',
    };
  }
  return 'Đã xảy ra lỗi, vui lòng thử lại.';
}
