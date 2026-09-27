---
name: snapshot
description: "Ghi chú làm việc thực tế cho app Snapshot (Flutter + Firebase). Dùng khi seed/sửa dữ liệu Firestore, build & kiểm thử trên iOS simulator, hoặc làm UI. Ghi lại các bẫy đã gặp để khỏi mất thời gian lặp lại."
---

# Snapshot — ghi chú làm việc

App mạng xã hội ảnh/video (Flutter + Firebase). Dưới đây chỉ là những thứ **hay vấp** — đọc trước khi làm các việc tương ứng.

## Dữ liệu seed (Firestore/Auth)
- **Đừng chạy script node `seed/*.mjs`** — bộ `firebase` JS hỏng trên node v24 (`ERR_UNSUPPORTED_DIR_IMPORT`). Thao tác dữ liệu bằng **REST API** (curl/python).
- API key và cấu hình project lấy trong `lib/firebase_options.dart`. Mật khẩu tài khoản seed do người dùng cung cấp — **không ghi key/mật khẩu vào code hay tài liệu**.
- Tài khoản seed: email dạng `seed.<username bỏ ký tự đặc biệt>@vibely.test`.
- Muốn ghi vào doc của user khác thì **đăng nhập bằng chính user đó** (rule chặn ghi chéo).
- Bộ đếm (like/comment/follower/post) là denormalized — sửa tay thì phải tính lại (`tools/maintenance/reconcile.mjs`). Không đặt số ảo.

## Ảnh bìa & lưới bài viết
- Bìa Unsplash phải ép **`fm=jpg`** (không dùng `auto=format`/WebP) — WebP hay lỗi giải mã trên simulator.
- `Post.coverUrl` lấy `thumbUrl` (nếu có) rồi mới tới `url`. Bài **ảnh** phải để `thumbUrl = ""` (rỗng) để tự fallback về `url`; chỉ bài **video** mới đặt `thumbUrl` là poster. `thumbUrl` rỗng-nhưng-tồn-tại từng làm bìa trống cả lưới.
- Ảnh mạng dùng widget `NetworkCover` (fade-in + retry) thay vì `CachedNetworkImage` trực tiếp.

## Khám phá (Explore)
- Explore chỉ hiện bài của người **chưa** theo dõi. Nếu tài khoản đã follow hết mọi người → tab trống. Muốn có nội dung: giữ đồ thị follow **một phần**, hoặc thêm user có bài mà tài khoản đang xem không follow.

## Build & test trên iOS simulator
- Toạ độ tap/swipe theo **điểm (393×852)**, KHÔNG phải pixel của ảnh chụp. Đổi: điểm = pixel ÷ chiều-rộng-ảnh × 393.
- Máy có 3 app `com.example.*` (snapshot/vimart/memento) — panel dễ nhảy nhầm app. Đưa Snapshot ra trước bằng lệnh `launch` của công cụ simulator (không phải `simctl launch`); tắt bớt 2 app kia nếu cần.
- Crash lúc mở app kiểu `Symbol not found: _FIRFirestore*` = lệch framework do build tăng tiến → `flutter clean` rồi build lại là hết.
- Đăng nhập tươi trên simulator hay bị từ chối dù đúng mật khẩu (giới hạn keychain/App Check). Ô nhập dễ bị autofill làm bẩn → nhấn giữ ô → **Select All** → gõ đè. Bấm mắt để kiểm tra mật khẩu trước khi than lỗi.
- Luôn chụp màn hình xác nhận sau mỗi thay đổi.

## UI (design system)
- Token ở `lib/core/design/tokens.dart`: dùng `AppText` (kiểu chữ theo vai trò), `AppColors`, `AppSpacing`, `AppRadius`, `AppMotion`, `AppGradients` — **không viết TextStyle/màu inline**.
- Chuyển động: helper `Motion` (tôn trọng reduced-motion + haptic) và primitive trong `lib/widgets/motion/` (`MotionEntrance`, `MotionSwitcher`, `MotionCountUp`, `Shimmer`/skeleton).
- Component dùng lại: `AvatarRing`, `AppCountBadge`, `AppTag`, `AppButton`, `NetworkCover`... (`lib/widgets/components/`).
- Hai skin sáng/tối (getter tự theo skin đang chạy). Tinh thần: *less but better* — nâng chất bằng phân cấp/khoảng cách/typography, không phủ card/gradient/shadow cho sang.

## Quy trình khi làm xong
`flutter analyze` sạch → build → kiểm thử trên simulator → commit (message tiếng Anh, Conventional Commits) → push `main`.
