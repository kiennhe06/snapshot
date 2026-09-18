# Snapshot

Ứng dụng mạng xã hội chia sẻ ảnh/video kiểu Instagram, xây bằng **Flutter + Firebase**.

## Tech stack
- **Flutter** (Dart), state management với **Riverpod**, điều hướng **go_router**
- **Firebase**: Authentication, Firestore, Storage, Cloud Functions, Cloud Messaging
- Cấu trúc nhóm theo feature (`lib/features/...`), tách UI ↔ logic ↔ data

## Tiến độ
- ✅ **Giai đoạn 1 — Nền tảng & Xác thực**: đăng ký/đăng nhập email, Google Sign-In, số điện thoại (OTP), quên mật khẩu, 2FA (MFA), đăng xuất, đa tài khoản + chuyển đổi nhanh, lịch sử đăng nhập/thiết bị.
- ⏳ Các giai đoạn sau: bảng tin, đăng ảnh/video, hồ sơ, stories, nhắn tin, thông báo đẩy.

## Thiết lập (sau khi clone)
Repo này **không kèm** file cấu hình Firebase (đã loại khỏi git để bảo mật). Tạo lại bằng FlutterFire CLI:

```bash
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

Sau đó điền **Web client id** (oauth_client type 3, lấy từ `google-services.json`) vào
`lib/core/constants.dart` → `AppConfig.googleWebClientId`, rồi chạy:

```bash
flutter run
```

## Firestore rules
Xem `firestore.rules`. Deploy: `firebase deploy --only firestore:rules`.
