# Snapshot

**Nền tảng mạng xã hội chia sẻ ảnh & video** — trải nghiệm hiện đại kiểu Instagram, chạy trên cả **iOS và Android** từ một mã nguồn duy nhất.

> Sản phẩm đã hoàn thiện các luồng cốt lõi và có sẵn dữ liệu demo để trải nghiệm ngay.

---

## Snapshot là gì?

Snapshot là mạng xã hội tập trung vào hình ảnh: người dùng đăng ảnh/video, xây dựng hồ sơ cá nhân, theo dõi và tương tác với nhau, khám phá nội dung mới và nhắn tin trực tiếp. Toàn bộ được gói trong giao diện mượt mà, nhất quán, có cả chế độ sáng và tối.

Sản phẩm phù hợp làm nền tảng cho **cộng đồng sáng tạo nội dung, nhiếp ảnh, thương hiệu cá nhân**, hoặc làm bộ khung sẵn sàng tuỳ biến cho một mạng xã hội hình ảnh riêng.

---

## Tính năng chính

### 📸 Nội dung & sáng tạo
- **Đăng bài đa dạng**: ảnh đơn, album nhiều ảnh (carousel) và video — kèm nhạc nền, gắn thẻ người dùng, vị trí và hashtag.
- **Stories**: khoảnh khắc tồn tại 24 giờ, tự động biến mất.
- **Reels**: video ngắn dạng cuộn dọc.
- **Hồ sơ cá nhân**: lưới bài viết, bài đã ghim, reels, bài được gắn thẻ; đổi ảnh đại diện ngay trong ứng dụng.

### 🔎 Kết nối & khám phá
- **Bảng tin thông minh**: xem bài từ người đang theo dõi, danh sách yêu thích, hoặc khám phá nội dung mới.
- **Khám phá**: tìm kiếm theo người dùng, hashtag, địa điểm; chủ đề thịnh hành và gợi ý người nên theo dõi.
- **Tương tác thật**: thích, bình luận, lưu bài — số liệu phản ánh đúng hành vi người dùng.
- **Nhắn tin trực tiếp** (DM/nhóm/broadcast) giữa các tài khoản.
- **Quản lý quan hệ**: theo dõi, chặn, hạn chế, ẩn từ khoá.

### 🔐 Tài khoản & an toàn
- **Đăng nhập linh hoạt**: email, Google, số điện thoại (OTP).
- **Bảo mật nâng cao**: xác thực hai lớp (2FA), lịch sử đăng nhập & thiết bị.
- **Đa tài khoản**: chuyển đổi nhanh giữa nhiều tài khoản trên cùng thiết bị.
- **Quyền riêng tư**: tài khoản riêng tư, chặn/ẩn người dùng, ẩn lượt thích.

---

## Trải nghiệm & thiết kế

- **Hệ thống thiết kế nhất quán** (design system): màu sắc, khoảng cách, kiểu chữ chuẩn hoá trên toàn ứng dụng — giao diện chỉn chu, dễ mở rộng và giữ đúng nhận diện thương hiệu.
- **Ngôn ngữ chuyển động riêng** (motion system): chuyển cảnh và phản hồi thao tác được thiết kế đồng bộ, tạo cảm giác cao cấp thay vì hiệu ứng chắp vá.
- **Chế độ sáng & tối**, tôn trọng thiết lập giảm chuyển động của người dùng.
- **Xử lý đầy đủ mọi trạng thái**: đang tải, trống, lỗi, thành công — không để màn hình đơ hay trắng.

---

## Nền tảng công nghệ & giá trị kinh doanh

| Công nghệ | Vì sao chọn | Lợi ích |
| --- | --- | --- |
| **Flutter** | Một mã nguồn cho cả iOS & Android | Giảm ~50% chi phí phát triển và bảo trì so với làm hai ứng dụng riêng |
| **Firebase** | Hạ tầng đám mây của Google | Tự động mở rộng theo lượng người dùng, dữ liệu thời gian thực, không cần vận hành máy chủ riêng |
| **Cloudinary** | Lưu trữ & tối ưu ảnh/video | Ảnh tải nhanh trên toàn cầu, tiết kiệm băng thông |

---

## Chất lượng & vận hành

- **Kiểm thử tự động (CI/CD)**: mỗi thay đổi đều được phân tích và chạy test trước khi hợp nhất, hạn chế lỗi lọt ra sản phẩm.
- **Tự động đồng bộ & dọn dẹp dữ liệu**: các bộ đếm (lượt thích, bình luận, người theo dõi) luôn khớp; nội dung hết hạn (story/note) tự xoá.
- **Chi phí tối ưu**: toàn bộ tự động hoá chạy trên gói miễn phí, **không yêu cầu nâng cấp gói trả phí**.

---

## Trạng thái sản phẩm

- ✅ **MVP hoàn chỉnh** các luồng cốt lõi: xác thực, bảng tin, đăng bài, hồ sơ, stories, khám phá, nhắn tin, reels, cài đặt.
- ⏳ **Chưa có**: thông báo đẩy (push/FCM) và bảng tin hoạt động trong app (activity feed) — xem `.claude/skills/snapshot/references/future.md`.
- ✅ **Dữ liệu demo sẵn sàng** — có thể cài và trải nghiệm ngay như một ứng dụng thật.
- 🎯 Sẵn sàng cho các bước tiếp theo: mở rộng tính năng, tuỳ biến thương hiệu, đưa lên cửa hàng ứng dụng.

---

## Dành cho lập trình viên

<details>
<summary>Cài đặt, cấu hình Firebase, quy ước dữ liệu — bấm để mở</summary>

### Tech stack
- **Flutter** (Dart), quản lý state bằng **Riverpod**, điều hướng **go_router**
- **Firebase**: Authentication, Firestore (chưa dùng Cloud Messaging/Storage)
- **Cloudinary** lưu trữ ảnh/video (upload trực tiếp, unsigned preset) — xem `lib/core/services/storage_service.dart`
- Design system: `lib/core/design/` • Motion system: `lib/widgets/motion/`
- Cấu trúc nhóm theo feature (`lib/features/...`), tách UI ↔ logic ↔ data

### Thiết lập (sau khi clone)
Repo **không kèm** file cấu hình Firebase (đã loại khỏi git để bảo mật). Tạo lại bằng FlutterFire CLI:

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

### Firestore rules & indexes
- Rules: `firestore.rules`
- Indexes (as code): `firestore.indexes.json`
- Deploy cả hai: `firebase deploy --only firestore:rules,firestore:indexes`

### Automation
Ba lớp tự động hoá bổ trợ nhau (không cần Blaze):

| Lớp | Nơi | Việc |
| --- | --- | --- |
| **CI** | `.github/workflows/ci.yml` | Mỗi push/PR lên `main` chạy `flutter analyze` + `flutter test` |
| **Firestore-as-code** | `firestore.indexes.json`, `scripts/enable-firestore-ttl.sh` | Index composite khai báo bằng code; TTL native tự xoá story/note hết hạn |
| **Reconcile** | `tools/maintenance/`, `.github/workflows/reconcile.yml` | Tính lại mọi bộ đếm + backfill `contributorIds` + dọn doc hết hạn |

Chi tiết reconcile: `tools/maintenance/README.md`.

### Dữ liệu demo (seed)
Firestore có sẵn các tài khoản demo (email `seed.<username>@vibely.test`, mật khẩu `seed12345`), kèm bài viết, like/comment thật và stories. Quy ước khi thêm/sửa:

- **Ảnh bìa**: URL Unsplash dạng `...?fm=jpg&fit=crop&w=..&h=..&q=..`. Ép `fm=jpg` (thay vì WebP) để tránh lỗi giải mã trên simulator.
- **`coverUrl`**: lấy `media.first.thumbUrl` rồi mới đến `url`. Bài **ảnh** để `thumbUrl` **rỗng** (`""`) — model coi chuỗi rỗng như không có và tự fallback sang `url` (xem `Post.coverUrl`). Chỉ bài **video** đặt `thumbUrl` là poster.
- **Khám phá** chỉ hiện bài của người **chưa** theo dõi — muốn tab này có nội dung, đồ thị follow phải **một phần** (đừng để mọi user follow tất cả).

</details>
