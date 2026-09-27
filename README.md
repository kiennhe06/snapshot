# Snapshot

Ứng dụng mạng xã hội chia sẻ ảnh/video kiểu Instagram, xây bằng **Flutter + Firebase**.

## Tech stack
- **Flutter** (Dart), state management với **Riverpod**, điều hướng **go_router**
- **Firebase**: Authentication, Firestore, Cloud Messaging
- **Cloudinary** cho lưu trữ ảnh/video (upload trực tiếp, unsigned preset) — xem `lib/core/services/storage_service.dart`
- **Design system** token-driven (`lib/core/design/`) + **Motion & Interaction System** riêng (`lib/widgets/motion/`)
- Cấu trúc nhóm theo feature (`lib/features/...`), tách UI ↔ logic ↔ data

## Tiến độ
- ✅ **Xác thực**: đăng ký/đăng nhập email, Google Sign-In, số điện thoại (OTP), quên mật khẩu, 2FA (MFA), đăng xuất, đa tài khoản + chuyển đổi nhanh, lịch sử đăng nhập/thiết bị.
- ✅ **Bảng tin** (`feed`): feed Đang theo dõi / Yêu thích / Khám phá, like & comment thật (transaction), lưu bài, header thu gọn khi cuộn.
- ✅ **Đăng bài** (`post`): ảnh/carousel/video, nhạc nền, tag người dùng, vị trí, hashtag.
- ✅ **Hồ sơ** (`profile`): grid bài viết, bài đã ghim, reels, bài được tag, đổi avatar trực tiếp.
- ✅ **Stories** (`stories`) & **Khám phá** (`explore`): tìm kiếm người dùng/hashtag/địa điểm, chủ đề thịnh hành, gợi ý người theo dõi.
- ✅ **Nhắn tin** (`messages`), **Tương tác/thông báo** (`interactions`), **Reels** (`reels`), **Cài đặt** (`settings`).
- ✅ **Trải nghiệm**: hệ thống typography theo vai trò (`AppText`), token màu ngữ nghĩa, skeleton/empty/error state, hai skin sáng–tối.

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

## Dữ liệu demo (seed)
Firestore có sẵn ~11 tài khoản demo để chạy thử (email `seed.<username>@vibely.test`, mật khẩu `seed12345`), kèm bài viết, like/comment thật và stories.

Một vài quy ước quan trọng khi thêm/sửa dữ liệu seed:

- **Ảnh bìa**: dùng URL Unsplash dạng `...?fm=jpg&fit=crop&w=..&h=..&q=..`. Ép `fm=jpg` (thay vì `auto=format`/WebP) để tránh lỗi giải mã trên simulator.
- **`coverUrl` của grid**: lấy từ `media.first.thumbUrl` rồi mới đến `media.first.url`. Với bài **ảnh** phải để `thumbUrl` **rỗng** (`""`) — model coi chuỗi rỗng như không có và tự fallback sang `url` (xem `Post.coverUrl`). Chỉ bài **video** mới đặt `thumbUrl` là poster.
- **Khám phá (Explore)** chỉ hiện bài của người bạn **chưa** theo dõi. Muốn tab này có nội dung, đồ thị follow phải **một phần** (đừng để mọi user follow tất cả) hoặc thêm user có bài mà tài khoản đang xem không follow.

> Lưu ý: script seed nằm ngoài repo; các thay đổi trên là quy ước dữ liệu, không phải cấu hình build.
