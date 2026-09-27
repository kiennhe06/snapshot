---
name: snapshot-ui
description: "Design system thực tế của Snapshot: token màu/typography/spacing/radius/motion, component dùng chung, và phân biệt LOCKED (không tự đổi) vs FLEXIBLE (được đề xuất cải tiến). Dùng khi làm bất kỳ UI nào, thêm màn hình, hoặc review giao diện. Triết lý: less but better."
---

# Snapshot — UI/UX Design System

Nguồn chân lý: `lib/core/design/tokens.dart` (+ `display_theme.dart`, `motion.dart`). **Không dùng giá trị inline** — luôn qua token.

## Token (giá trị thật)
- **Spacing** (`AppSpacing`): xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24.
- **Radius** (`AppRadius`): xxs 6 · xs 10 · sm 12 · md 16 · lg 20 · xl 24 · xxl 28 · pill 999.
- **Icon** (`AppIconSize`): xxs 12 · xs 14 · sm 16 · md 20 · lg 24 · xl 28.
- **Type size** (`AppType`): display 30 · title 20 · headline 16 · subhead 15 · body 13 · label 12 · small 11 · caption 10.
- **Typography role** (`AppText`, getter theo skin): `display, h1, h2, h3, body, bodyStrong, bodyMuted, label, caption, button` — có sẵn line-height + letter-spacing. **Dùng AppText, không tự ghép TextStyle.**
- **Màu** (`AppColors`, getter theo skin): nền/lớp `layer1..3`, `textPrimary/Secondary/Tertiary`, primary + `onPrimary/onPrimaryMuted/onMedia/onMediaMuted`, `AppGradients`, `AppShadows`, `AppBackground`, `AppDepth`.
- **Motion** (`AppMotion` + helper `Motion` trong `core/design/motion.dart`): tempo (micro→grand), easing (enter/exit/emphasized/overshoot), spring (snappy/gentle/bouncy), stagger; helper tôn trọng **reduced-motion** + haptic (tap/toggle/selection/success).

## Skin
- **2 skin runtime** `DisplaySkin { light, dark }`: **"Moment"** (light, hồng nhạt, airy) và **"Nova"** (dark, near-black sáng tạo). Đổi trong Settings → Display. Token là **getter** nên tự theo skin đang chạy — mọi màu phải qua token để đúng cả 2 skin. (Màn auth có xử lý màu riêng.)

## Component dùng lại (ưu tiên trước khi tự vẽ mới)
`AppButton`, `AppGradientButton`, `AppScaffold`, `AppTopBar`, `AppBottomSheet`/`AppSheet`, `AppToast` (dùng `showAppToast`, không SnackBar), `AppTextField`, `AppTile`, `AppToggleRow`/`AppSwitch`, `AppTabs`, `AppCard`, `AppFilterChip`, `AppSectionLabel`, `AppBottomNav`, `AvatarRing`, `AppCountBadge`/`AppTag` (app_badge), `NetworkCover` (ảnh mạng: fade-in + retry), `AppVideo`, `PressScale`. Motion: `MotionEntrance`, `MotionSwitcher`, `MotionCountUp`, `Shimmer`/`SkeletonBox`, `ListRowsSkeleton`.

## Trạng thái (bắt buộc xử lý đủ)
Loading / empty / error / success. Dùng `AsyncValueView` (bọc branch, có skeleton) + `EmptyView` + `ErrorView` (có retry). Đừng để màn trắng hay spinner kẹt. Ảnh lỗi → placeholder sạch (`postCoverPlaceholder`), không hiện icon broken-image.

## Triết lý (yêu cầu của người dùng)
**Less but better, không phải more but cluttered.** Nâng chất bằng phân cấp/khoảng cách/typography/nhất quán — KHÔNG phủ thêm card/gradient/shadow/animation để "cho sang". Không lạm dụng card. Icon nhất quán.

## LOCKED DESIGN (không tự ý đổi — chỉ đổi khi người dùng yêu cầu)
- Hệ token trong `tokens.dart` (thang spacing/radius/type, bộ màu 2 skin) và bộ role `AppText`.
- Bố cục các màn đã chốt theo mockup "VibeFeed": **feed home post card, Explore, create-post, comments, sign-in/sign-up, reel composer** (nhiều commit "match mockup"/"redesign to match").
- **Motion language** (AppMotion + primitives) — đã xây có chủ đích thành hệ thống, không thêm animation lẻ chắp vá.
- Header thu gọn khi cuộn ở Home & Profile; grid 3 cột hồ sơ; navigation bottom bar.
- Hành vi đã tối ưu: like lạc quan (optimistic), double-tap-to-like heart burst + haptic.

## FLEXIBLE DESIGN (được ĐỀ XUẤT cải tiến — vẫn hỏi trước khi đổi lớn)
- Thêm empty/error state còn thiếu; cải thiện thông điệp lỗi.
- Trích thêm component tái sử dụng từ pattern lặp; dọn TextStyle/màu inline còn sót (~152 chỗ one-off).
- Reconcile kích thước icon (12/14/16/20/24/28) nếu có chỗ lệch thang.
- Accessibility: contrast, semantics/label, target size.
- Tinh chỉnh spacing/typography theo thang token (không phá thang).

> Khi phân vân LOCKED hay FLEXIBLE: nếu nó thuộc mockup đã chốt hoặc hệ token/motion → LOCKED, đề xuất trước. Nếu là state thiếu / dọn nợ / a11y → FLEXIBLE, vẫn báo trước khi đổi diện rộng.
