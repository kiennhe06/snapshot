---
name: snapshot-architecture
description: "Kiến trúc thực tế của Snapshot: folder structure feature-first, các module chính và dependency, data flow Firestore/Cloudinary, state management Riverpod, và các phần dễ gây regression nhất. Dùng khi cần hiểu code nằm ở đâu, thay đổi ảnh hưởng tới đâu, hoặc trước khi sửa module dùng chung."
---

# Snapshot — Kiến trúc thực tế

## Công nghệ (từ `pubspec.yaml`)
Flutter · Dart · **flutter_riverpod** (state) · **go_router** (điều hướng) · **firebase_core/auth + cloud_firestore** · **google_sign_in** · **image_picker/image_cropper/image** · **cached_network_image** · **video_player/audioplayers/record** · **http** (gọi Cloudinary + iTunes) · **shared_preferences** (creds/cài đặt cục bộ) · **google_fonts** · **qr_flutter** · device/package_info_plus. Media KHÔNG dùng Firebase Storage — dùng **Cloudinary** (`lib/core/services/storage_service.dart`).

## Folder structure
```
lib/
  app/            app.dart, router.dart (go_router + Routes.*), theme.dart
  core/
    design/       tokens.dart (AppColors/Spacing/Radius/Type/Text/Motion/Shadows/Gradients...), display_theme.dart, motion.dart
    i18n/         tr('vi','en') — song ngữ VI/EN (539 chỗ dùng tr())
    services/     storage_service.dart (Cloudinary), spotify_service.dart, image_edit_service.dart
    utils/        auth_error.dart (map lỗi Firebase → tiếng Việt), format.dart
  features/<tên>/ data/ (repository) · providers/ (Riverpod) · presentation/ (screen+widget)
  models/         app_user, post, comment, story, chat, login_session, stored_account, post_draft, spotify_track
  widgets/
    components/   AppButton, AppScaffold, AppTopBar, AppBottomSheet, AppToast, AppTextField, AppTile,
                  AppTabs, AppCard, AppFilterChip, AvatarRing, AppBadge, NetworkCover, AppVideo, PressScale...
    motion/       MotionEntrance, MotionSwitcher, MotionCountUp, Shimmer/SkeletonBox, ListRowsSkeleton
    async_value_view.dart, empty_view.dart, error_view.dart, loading_view.dart
```
Features: `auth, feed, post, profile, explore, stories, reels, messages, interactions, settings, home`. Mỗi feature tách `data ↔ providers ↔ presentation` (một số nhỏ như `home/settings` chỉ có presentation).

## State management (Riverpod)
- Chủ yếu **Provider / StreamProvider (32) / FutureProvider (12) / Notifier (11) / AsyncNotifier (2)**. Không dùng StateNotifier/ChangeNotifier.
- Stream provider bọc query Firestore realtime; Notifier giữ state có thao tác (vd `FeedController`).
- UI bọc async bằng `AsyncValueView` (đã hợp nhất loading/empty/error, có skeleton).

## Data flow
1. **Đọc**: Screen → `ref.watch(...Provider)` → repository (`features/*/data`) → Firestore stream/query → model `fromMap` → UI.
2. **Ghi**: UI → repository → Firestore (transaction cho like/comment để đếm đúng) → stream tự cập nhật UI.
3. **Media**: chọn ảnh (image_picker) → (crop/edit) → upload **Cloudinary** (`storage_service`) → lưu URL vào Firestore doc.
4. **Đếm**: các count (likes/comments/followers/following/posts) **denormalized** trên doc; tool `tools/maintenance/reconcile.mjs` tính lại.

## Auth / Authorization
- **firebase_auth**: email, Google, phone OTP, MFA (2FA). Đa tài khoản + chuyển nhanh (`stored_account`), lịch sử đăng nhập (`login_session`), Remember me (shared_preferences), dev auto-login qua `--dart-define`.
- `handlePostSignIn(...)` chạy sau đăng nhập. Lỗi keychain trên simulator được xử lý riêng trong `core/utils/auth_error.dart` (`isKeychainError`) — sign-in vẫn coi là thành công nếu user còn trong bộ nhớ.
- **Authorization**: `firestore.rules` (203 dòng) — collections: users, posts, comments, likes, saved, favorites, following, followers, blocked, muted, restricted, stories, views, highlights, chats, messages, typing, sessions, reports, aggregates, usernames, meta. Ghi doc của user khác thường bị chặn → thao tác REST phải đăng nhập đúng chủ.

## Module chính & dependency (đọc để biết impact)
- `core/design/tokens.dart` — **mọi UI phụ thuộc**. Đổi token = ảnh hưởng toàn app.
- `widgets/components/*` + `widgets/motion/*` — dùng chung nhiều màn. Sửa 1 component = kiểm mọi nơi dùng.
- `models/post.dart` (`Post.coverUrl`, `isVideo`, `coAuthorIds`) — feed, grid, explore đều đọc. Xem skill `snapshot-anti-regression`.
- `features/feed/providers/feed_providers.dart` — `FeedController` + `_applyAudience` lọc theo following/blocked/muted/visibility cho cả 3 feed (following/favorites/explore).
- `core/i18n` — mọi text người dùng đi qua `tr()`.

## Phần DỄ GÂY REGRESSION nhất
1. **`Post.coverUrl` / logic media** — feed đọc `media.url`, grid đọc `coverUrl` (ưu tiên `thumbUrl`). Lệch nhau từng gây bìa trống.
2. **`_applyAudience` trong feed_providers** — đổi điều kiện lọc ảnh hưởng cả 3 feed cùng lúc.
3. **`core/design/tokens.dart`** — thay đổi lan toàn app + cả 2 skin.
4. **Component dùng chung** (AppButton, AppTopBar, AppBottomSheet, AsyncValueView, NetworkCover...).
5. **Luồng auth + keychain trên simulator** — dễ tưởng bug app nhưng là giới hạn môi trường.
6. **Firestore rules** — thắt/nới sai làm vỡ đọc/ghi im lặng.
