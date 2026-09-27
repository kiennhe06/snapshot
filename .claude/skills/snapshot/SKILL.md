---
name: snapshot
description: "Kiến thức dự án Snapshot (Flutter + Firebase, mạng xã hội ảnh/video). Đọc ĐẦU TIÊN khi làm bất kỳ task nào trong repo này: tóm tắt project, kiến trúc, quy tắc quan trọng, cách bắt đầu task. Chi tiết nằm trong references/ (architecture, conventions, ui, workflow, debugging, anti-regression, decisions, future) — đọc file tương ứng khi cần."
---

# Snapshot — Project Memory (đọc trước tiên)

> Đây là điểm vào. Chi tiết theo chủ đề nằm trong `references/*.md` — đọc file tương ứng khi task chạm tới nó.

## Project là gì
Mạng xã hội chia sẻ ảnh/video kiểu Instagram, tên **Snapshot** (project Firebase tên `vibely-90fda`, từng gọi là "Vibely"/"VibeFeed"). Xây bằng **Flutter + Firebase**, một mã nguồn cho iOS & Android. Giao tiếp và tài liệu bằng **tiếng Việt**; code/commit bằng **tiếng Anh**.

## Người dùng mục tiêu
Cộng đồng sáng tạo nội dung, nhiếp ảnh, thương hiệu cá nhân. Hiện là **MVP có dữ liệu demo thật** (tài khoản seed) để trải nghiệm như app thật.

## Hiện trạng (tính đến commit `880074b`, 87 commits)
Đã xong các luồng cốt lõi: **xác thực** (email/Google/OTP, 2FA, đa tài khoản), **feed** (Đang theo dõi/Yêu thích/Khám phá), **đăng bài** (ảnh/carousel/video + nhạc + tag + vị trí + hashtag), **hồ sơ**, **stories**, **reels**, **nhắn tin** (DM/nhóm/broadcast), **tương tác/thông báo**, **khám phá/tìm kiếm**, **cài đặt**. Có **design system** token-driven, **motion system** riêng, 2 skin sáng/tối, i18n VI/EN.

## Kiến trúc 1 dòng
Flutter + Riverpod (Notifier/StreamProvider/FutureProvider) + go_router; feature-first (`lib/features/<tên>/{data,providers,presentation}`); Firestore là backend realtime; **Cloudinary** lưu ảnh/video (KHÔNG dùng Firebase Storage). Chi tiết: `references/architecture.md`.

## 6 quy tắc quan trọng nhất (vi phạm = hỏng/regression)
1. **Đọc code thực tế trước, tin code hơn docs.** Docs/README từng lệch với code. Bug bìa grid mất nhiều thời gian vì không đọc getter `Post.coverUrl` sớm.
2. **Không tự ý refactor/đổi kiến trúc/đổi dependency** khi task chỉ là sửa nhỏ. Không xoá code đang chạy vì "nghĩ là dư".
3. **Không kết luận "đã fix" khi chưa kiểm thử behavior thật trên simulator** (chụp màn hình xác nhận). Đây là yêu cầu lặp lại của người dùng.
4. **Không đặt số liệu ảo** (like/comment/follower "buff ảo") — người dùng phản đối rõ. Dùng tương tác thật hoặc để 0.
5. **Không để lộ secret** (API key, mật khẩu) trong file commit — repo push công khai.
6. **Đề xuất cải tiến, KHÔNG tự triển khai** thay đổi rủi ro. Hỏi/xác nhận trước khi làm việc có impact lớn.

## Cách bắt đầu một task mới
Theo `references/workflow.md`. Tóm tắt: hiểu yêu cầu → đọc code liên quan → xác định impact (search caller/usage) → làm thay đổi nhỏ → `flutter analyze` → build & kiểm thử simulator → chụp xác nhận → commit (Conventional Commits, tiếng Anh) → push `main`.

## Các file tham chiếu (đọc khi cần)
- `references/architecture.md` — cấu trúc, module, data flow, phần dễ regression.
- `references/conventions.md` — quy ước code thực tế của project.
- `references/ui.md` — design system + LOCKED vs FLEXIBLE.
- `references/workflow.md` — quy trình + master checklist.
- `references/debugging.md` — playbook debug + pattern riêng.
- `references/anti-regression.md` — NEVER/ALWAYS + bảng rủi ro theo loại thay đổi.
- `references/decisions.md` — decision log + preferences (đừng vô tình "sửa lại" quyết định có chủ ý).
- `references/future.md` — technical debt, cơ hội, ý tưởng (chỉ đề xuất).
