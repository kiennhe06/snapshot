# Snapshot — Anti-Regression System

## NEVER DO AGAIN (có căn cứ từ project)
- ❌ **Kết luận "đã fix" khi chưa kiểm thử behavior thật** trên simulator (yêu cầu lặp lại của người dùng).
- ❌ **Đoán hạ tầng (cache/decode/kích thước/mạng) trước khi so đường code** — bug bìa grid mất nhiều vòng vì bỏ qua getter `Post.coverUrl`.
- ❌ **Hành động phá huỷ/không hồi phục dựa trên giả thuyết chưa xác minh** (gỡ app → wipe session → kẹt đăng nhập).
- ❌ **Đặt số liệu ảo** (like/comment/follower "buff ảo") — người dùng phản đối.
- ❌ **Refactor lớn / đổi kiến trúc / đổi dependency khi task chỉ là sửa nhỏ.**
- ❌ **Xoá code đang chạy vì "nghĩ là dư"** mà chưa kiểm usage.
- ❌ **Giả định một function/field chỉ có một caller/một nguồn** (feed vs grid đọc media khác đường).
- ❌ **Sửa module shared (token/component/model/provider) mà không search toàn bộ usage.**
- ❌ **Đổi UI/behavior đã chốt theo mockup** mà không hỏi.
- ❌ **Để lộ secret** (key/mật khẩu) trong file commit — repo push công khai.
- ❌ **Ghi dữ liệu chung Firestore (follow graph/counts) mà chưa được người dùng đồng ý.**
- ❌ **Dùng `?? ` cho String mà quên bẫy chuỗi rỗng** (`"" ?? x` = `""`).

## ALWAYS DO
- ✅ Đọc code thực tế trước khi sửa (tin code hơn docs).
- ✅ Search toàn bộ usage trước khi đổi shared code; đọc từng caller.
- ✅ Xác định impact + LOCKED/FLEXIBLE trước khi làm.
- ✅ Thay đổi nhỏ, có thể kiểm chứng; giữ nguyên behavior không liên quan.
- ✅ `flutter analyze` sạch → build → kiểm thử simulator → chụp xác nhận.
- ✅ Kiểm cả 2 skin (Moment/Nova) khi đụng token/màu.
- ✅ Với bug "chỗ chạy chỗ không": so đường code/data hai nơi trước.
- ✅ Báo cáo trung thực: đã verify gì, chưa chắc gì.

## Bảng rủi ro theo loại thay đổi
| Loại thay đổi | Rủi ro | Phải kiểm | Phải test |
| --- | --- | --- | --- |
| Sửa `models/post.dart` (coverUrl/media/getter) | Cao — feed, grid, explore, pinned đều đọc | Mọi nơi đọc field đó | Feed + grid hồ sơ + Explore hiện ảnh đúng |
| Sửa `feed_providers.dart` `_applyAudience` | Cao — 3 feed chung 1 hàm lọc | following/favorites/explore | Cả 3 tab feed đúng nội dung |
| Sửa `core/design/tokens.dart` | Cao — toàn app + 2 skin | Chỗ dùng token đổi | Rà nhiều màn, cả sáng & tối |
| Sửa component `widgets/components/*` | Trung–cao — nhiều màn | Mọi nơi import | Các màn dùng component đó |
| Sửa auth / handlePostSignIn | Cao — chặn vào app | keychain path, provider trước await | Đăng nhập lại được (lưu ý giới hạn sim) |
| Sửa `firestore.rules` | Cao — vỡ đọc/ghi im lặng | collection liên quan | Đọc/ghi thật của user thường |
| Đổi seed data / follow graph / counts | Trung — dữ liệu chung | Rule cho phép ghi? | Feed/Explore/counts sau khi đổi + reconcile |
| Thêm UI mới thuần | Thấp | Token/component tái dùng | Loading/empty/error/success |
| Build tăng tiến sau đổi Firebase deps | Trung — lệch framework | — | Nếu crash symbol → `flutter clean` |

## Behavior / UI KHÔNG được phá (chốt có chủ đích)
- Like lạc quan (optimistic) ở feed/reels; double-tap-to-like heart burst + haptic.
- Header thu gọn khi cuộn (Home & Profile); grid 3 cột hồ sơ; bottom nav.
- Motion language (AppMotion + primitives) — hệ thống, không thêm animation lẻ.
- Bố cục các màn theo mockup VibeFeed (feed card, Explore, create-post, comments, auth, reel composer).
- i18n: mọi text người dùng qua `tr()`, giữ song ngữ VI/EN.
- Trạng thái thống nhất qua `AsyncValueView`/`AppToast`.

## Error forensics (tóm tắt các lỗi đã gặp → phân loại → rule)
> Phân loại: A Requirement · B Architecture · C Coding · D Dependency · E State/data-flow · F UI/UX · G Testing · H Communication · I AI reasoning · J Other.

1. **Bìa grid trống** — `coverUrl` trả `""` do `thumbUrl=""` (`"" ?? url` = `""`). Loại **C+E+I**. Không phát hiện sớm vì bỏ qua getter, đi nghi hạ tầng. Rule: *bug "chỗ chạy chỗ không" → so accessor/đường data trước.* Fix đúng (đã verify trên sim).
2. **Ảnh WebP không hiện trên sim** — `auto=format`. Loại **E/J**. Rule: *bìa seed ép `fm=jpg`.*
3. **Gỡ app làm mất session → kẹt login** — hành động phá huỷ theo giả thuyết sai (cache). Loại **I**. Rule: *không phá huỷ khi chưa xác minh; bug này vốn không liên quan cache.*
4. **Crash `_FIRFirestoreErrorDomain`** — build tăng tiến lệch framework. Loại **D/G**. Rule: *crash symbol Firebase → `flutter clean`.*
5. **Login sim từ chối creds đúng** — giới hạn keychain/App Check. Loại **J (môi trường)**. Rule: *đây là hạn chế simulator, không phải bug creds.*
6. **Mis-tap khi login** — nhầm toạ độ pixel vs điểm. Loại **G**. Rule: *toạ độ theo điểm 393×852.*
7. **(từ tóm tắt phiên trước) Feed spinner vô hạn** — `loadMore` thiếu try/catch. Loại **C/E**. Rule: *async có nhánh lỗi + retry.*
8. **(từ tóm tắt) Grid trống** — query `contributorIds` nhưng seed `[]`. Loại **E**. Rule: *khớp điều kiện query với dữ liệu thật.*
9. **(từ tóm tắt) CI đỏ** — `firebase_options.dart` gitignore thiếu khi checkout. Loại **D/G**. Rule: *CI dùng stub.*
10. **Suýt commit key trong SKILL** — chặn kịp trước commit. Loại **J (bảo mật)**. Rule: *quét secret trước khi commit file tài liệu.*
