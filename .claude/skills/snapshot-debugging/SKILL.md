---
name: snapshot-debugging
description: "Playbook debug cho Snapshot + các pattern debug riêng của project (Flutter/Firebase/iOS simulator). Dùng khi có bug hiển thị, crash, dữ liệu sai, hoặc hành vi khác mong đợi. Nhấn mạnh: tìm root cause bằng cách so đường code, không đoán mò hạ tầng."
---

# Snapshot — Debugging Playbook

## Quy trình 10 bước
1. **Reproduce** — tái hiện chính xác trên simulator, chụp màn hình.
2. **Identify scope** — chỗ nào lỗi, chỗ nào bình thường? (rất quan trọng, xem bài học dưới).
3. **Inspect logs/errors** — crash report (`~/Library/Logs/DiagnosticReports/Runner-*.ips`), console, `flutter analyze`.
4. **Trace data flow** — lần từ UI → provider → repository → Firestore/model. Đọc getter/accessor liên quan.
5. **Find root cause** — nguyên nhân gốc, không phải triệu chứng.
6. **Form hypothesis** — 1 giả thuyết kiểm chứng được; ưu tiên giả thuyết ít tốn kém & không phá huỷ.
7. **Make minimal change** — sửa nhỏ nhất.
8. **Test** — verify behavior thật.
9. **Regression test** — vùng liên đới.
10. **Document lesson** — nếu là bẫy hệ thống, cập nhật skill tương ứng.

## Bài học cốt lõi (từ bug bìa grid trống)
Khi **một giá trị hiển thị đúng ở chỗ này nhưng sai ở chỗ khác** (feed hiện ảnh, grid trống): **so sánh chính xác đường code/accessor của hai nơi TRƯỚC** khi nghi decode/cache/kích thước/mạng. Ở đây: feed đọc `media.url`, grid đọc `Post.coverUrl` (ưu tiên `thumbUrl` rỗng) → cùng URL nhưng grid nhận `""`. Đã mất nhiều vòng vì đi nghi memCacheWidth/WebP/cache trước. → **Đọc getter/mapping trước, hạ tầng sau.**

## Đừng phá huỷ khi chưa xác minh
Không xoá app / wipe session / reset data để "thử" khi giả thuyết chưa chắc. Việc gỡ app để xoá cache đã làm **đăng xuất** và kéo theo cả chuỗi lỗi đăng nhập trên simulator — trong khi bug thật là lỗi code/data không liên quan cache.

## Pattern debug riêng của project

| Triệu chứng | Nhiều khả năng là | Cách xử lý |
| --- | --- | --- |
| Bìa/ảnh grid trống nhưng feed ok | `coverUrl` rỗng do `thumbUrl=""`; hoặc `media` vs `coverUrl` khác nguồn | Đọc `Post.coverUrl`; bài ảnh để `thumbUrl` rỗng để fallback `url` |
| Ảnh 200 khi curl nhưng không hiện trên sim | WebP (`auto=format`) sim khó giải mã | Ép URL `fm=jpg` |
| Crash mở app `Symbol not found: _FIRFirestore*` | Build tăng tiến lệch framework | `flutter clean` + build lại |
| Đăng nhập đúng creds vẫn bị từ chối trên sim | Giới hạn keychain/App Check của simulator, KHÔNG phải sai creds | Xác nhận creds đúng (bấm mắt); biết đây là môi trường; session cũ persist thì vẫn chạy |
| Feed quay spinner vô hạn | Thao tác async thiếu try/catch (vd `loadMore`) | Thêm error state + retry |
| Grid/feed trống dù có bài | Query lọc theo field seed để trống (vd `contributorIds=[]`) | Kiểm điều kiện query vs dữ liệu thật |
| Explore trống | Đã follow hết → không còn gì để khám phá | Đồ thị follow một phần / thêm author chưa follow |
| Count (like/follower) sai | Denormalized lệch | `tools/maintenance/reconcile.mjs` |
| CI đỏ ở analyze | `lib/firebase_options.dart` gitignore, thiếu khi checkout sạch | CI copy stub `ci/firebase_options.stub.dart` |

## Công cụ dữ liệu (không qua app)
Thao tác Firestore/Auth bằng **REST API** (curl/python) — bộ `firebase` node hỏng trên node v24. Key lấy từ `lib/firebase_options.dart`, **không viết key/mật khẩu vào file commit**. Ghi doc user khác phải đăng nhập đúng chủ. (zsh: đừng dùng biến shell tên `UID` — reserved.)

## Simulator
Toạ độ tap/swipe theo **điểm 393×852**, không phải pixel ảnh (điểm = pixel ÷ rộng-ảnh × 393). Có 3 app `com.example.*` dễ nhảy nhầm panel — đưa app cần test ra trước bằng lệnh `launch` của tool. Ô nhập login dễ bị autofill làm bẩn → nhấn giữ → Select All → gõ đè.
