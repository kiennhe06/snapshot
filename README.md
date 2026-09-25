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

## Firestore rules & indexes
- Rules: `firestore.rules`
- Indexes (as code): `firestore.indexes.json`
- Deploy cả hai: `firebase deploy --only firestore:rules,firestore:indexes`

## Automation
Ba lớp tự động hoá bổ trợ nhau (không cần Blaze):

| Lớp | Nơi | Việc |
| --- | --- | --- |
| **CI** | `.github/workflows/ci.yml` | Mỗi push/PR lên `main` chạy `flutter analyze` + `flutter test` |
| **Firestore-as-code** | `firestore.indexes.json`, `scripts/enable-firestore-ttl.sh` | Index composite khai báo bằng code; TTL native tự xoá story/note hết hạn (chạy `scripts/enable-firestore-ttl.sh` một lần) |
| **Reconcile** | `tools/maintenance/`, `.github/workflows/reconcile.yml` | Tính lại mọi bộ đếm (like/comment/follower/post) + backfill `contributorIds` + dọn doc hết hạn. Chạy tay hoặc theo lịch hằng tuần |

Chi tiết reconcile: `tools/maintenance/README.md`.
