# Snapshot — Workflow & Master Checklist

## Quy trình chuẩn cho một task
```
NHẬN TASK
  → HIỂU YÊU CẦU (mơ hồ hoặc có ≥2 hướng hợp lý → hỏi; rõ → làm luôn)
  → ĐỌC CODE LIÊN QUAN (tin code hơn docs)
  → XÁC ĐỊNH IMPACT (search caller/usage nếu đụng model/provider/component chung)
  → KẾ HOẠCH (thay đổi nhỏ nhất đủ giải quyết; không refactor kèm)
  → LÀM
  → flutter analyze (phải sạch)
  → BUILD + KIỂM THỬ TRÊN SIMULATOR (chụp màn hình xác nhận)
  → REGRESSION CHECK (những vùng liên đới — xem `references/anti-regression.md`)
  → COMMIT (Conventional Commits, tiếng Anh) → PUSH main
  → BÁO CÁO trung thực (làm gì, kết quả thật, còn gì chưa chắc)
```
Điều chỉnh theo bài học: (1) với bug hiển thị, tìm **khác biệt data/đường code giữa nơi chạy được và nơi lỗi** TRƯỚC khi nghi hạ tầng; (2) không làm hành động phá huỷ/không hồi phục (xoá app, wipe session, reset data) dựa trên giả thuyết chưa xác minh.

## Khi nào HỎI vs TỰ CHỦ (theo preference người dùng)
- **Tự làm**: yêu cầu rõ; sửa bug; thay đổi nhỏ có thể kiểm chứng; commit+push khi xong (analyze sạch).
- **Hỏi trước**: có ≥2 phương án hợp lý khác nhau về data/architecture; thay đổi dữ liệu chung (follow graph, counts) — từng bị guard "Modify Shared Resources" chặn; đổi UI đã chốt; bất kỳ việc rủi ro/khó hồi phục.
- **Đề xuất, KHÔNG tự làm**: các cải tiến trong `references/future.md`.

## MASTER CHECKLIST

### BEFORE CODING
- [ ] Hiểu đúng yêu cầu (không suy diễn thêm phạm vi).
- [ ] Đọc code thực tế của phần sẽ sửa (không dựa vào README/docs).
- [ ] Nếu đụng model/provider/component/token dùng chung → search toàn bộ usage/caller.
- [ ] Xác định đây là LOCKED hay FLEXIBLE (`references/ui.md`).

### DURING CODING
- [ ] Thay đổi nhỏ nhất; giữ nguyên behavior không liên quan.
- [ ] Dùng token + component sẵn có; không TextStyle/màu inline.
- [ ] Không nuốt lỗi; async có nhánh lỗi; dispose controller.
- [ ] Không thêm dependency mới nếu chưa cần/không giải thích.

### AFTER CODING
- [ ] `flutter analyze` sạch (0 issue).
- [ ] Build simulator OK (nếu crash symbol Firebase → `flutter clean` rồi build lại).
- [ ] Kiểm thử behavior thật + **chụp màn hình**.

### BEFORE CLAIMING DONE
- [ ] Đã thấy kết quả đúng trên máy thật/simulator, không chỉ "code có vẻ đúng".
- [ ] Kiểm vùng liên đới (regression).
- [ ] Không lộ secret trong file commit.
- [ ] Báo cáo nêu rõ cái gì đã verify, cái gì chưa chắc.

### BEFORE REFACTORING
- [ ] Task có thực sự cần refactor không? (task sửa nhỏ thì KHÔNG kèm refactor).
- [ ] Liệt kê file/usage bị ảnh hưởng; có cách hoàn tác.

### BEFORE MODIFYING SHARED CODE (model / provider / component / token)
- [ ] Search mọi nơi dùng; đọc từng caller.
- [ ] Đừng giả định "chỉ có một caller".
- [ ] Kiểm cả 2 skin nếu đụng token/màu.

### BEFORE CHANGING ARCHITECTURE / SHARED DATA
- [ ] Có lý do rõ ràng + đồng ý của người dùng.
- [ ] Với dữ liệu chung (Firestore graph/counts): xác nhận trước, không tự ghi.
