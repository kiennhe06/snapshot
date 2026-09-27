# Snapshot — Future / Improvements (chỉ đề xuất)

> KHÔNG tự biến các mục dưới thành thay đổi code. Đề xuất → xác định impact → chờ quyết định nếu rủi ro lớn.
> Nhãn: **[KNOWN]** có bằng chứng · **[RISK]** rủi ro tiềm tàng · **[IDEA]** suy đoán/đề xuất.

## Technical debt (hiện trạng)
- **[KNOWN] Test gần như không có** — chỉ `test/widget_test.dart`. Không có unit/widget/integration test cho model, provider, repository. → Rủi ro regression cao khi sửa shared code.
- **[KNOWN] Còn ~152 TextStyle/màu inline** rải rác (one-off) chưa chuyển hết sang token.
- **[KNOWN] Seed data có `thumbUrl=""`** ở bài ảnh — code đã fallback đúng, nhưng dữ liệu vẫn "bẩn". Có thể dọn.
- **[KNOWN] `firebase_options.dart` gitignore + stub CI** — hoạt động nhưng dễ nhầm cho người mới.
- **[RISK] Denormalized counts** — lệch nếu ghi tay/không reconcile; phụ thuộc job reconcile chạy đều.

## Rủi ro nếu tiếp tục 3–6 tháng
- **[RISK] Scalability đọc feed**: `_applyAudience` lọc phía client sau khi fetch trang — với nhiều bài/nhiều following có thể tốn kém. Cần đo trước khi kết luận.
- **[RISK] Security/rules**: `firestore.rules` 203 dòng, nhiều collection — cần rà quyền ghi chéo (follow/counts) kỹ; chưa có test rules.
- **[RISK] Auth trên thiết bị thật vs simulator**: đã có xử lý keychain, nhưng luồng đăng nhập tươi cần kiểm trên thiết bị thật.
- **[RISK] Cloudinary unsigned preset**: tiện nhưng cần xem giới hạn/abuse nếu mở công khai.
- **[RISK] Media/perf**: video + ảnh lớn trong feed/reels — cần đo jank, đã có cap decode size nhưng chưa đo hệ thống.

## Missed opportunities (phân mức, KHÔNG tự sửa)
| Cơ hội | Mức |
| --- | --- |
| Thêm test cho `Post.coverUrl`, `_applyAudience`, auth error mapping (các chỗ từng có bug) | **SHOULD IMPROVE** |
| CI chạy được test thật (hiện chỉ analyze + 1 widget test) | **SHOULD IMPROVE** |
| Dọn TextStyle inline còn lại; reconcile thang icon size | **NICE TO HAVE** |
| Dọn `thumbUrl=""` trong seed | **NICE TO HAVE** |
| Rules test (emulator) cho quyền ghi chéo | **SHOULD IMPROVE** |
| Tài liệu "chạy seed bằng REST" gọn cho người mới | **NICE TO HAVE** |

## Breakthrough ideas (đề xuất — mỗi ý là proposal)
> Chỉ nêu ý có vấn đề thật để giải, không thêm tính năng cho có.

**I1. [IDEA] Golden/regression test cho các màn LOCKED theo mockup.**
- Vấn đề: UI chốt theo mockup dễ bị phá âm thầm khi refactor.
- Cách: golden test cho feed card / Explore / auth ở cả 2 skin.
- Khó: trung bình · Rủi ro: thấp · Lợi: chặn regression UI · Phụ thuộc: hạ tầng test.
- Thời điểm: **NEXT**.

**I2. [IDEA] Ranking Explore/For-You theo tín hiệu (thay vì chỉ "chưa follow").**
- Vấn đề: Explore hiện đơn giản; dễ trống/thiếu liên quan.
- Cách: điểm theo hashtag/tương tác/gần đây; vẫn client-side hoặc thêm field xếp hạng.
- Khó: cao · Rủi ro: trung (đụng `_applyAudience`) · Lợi: giữ chân người dùng.
- Thời điểm: **LATER**.

**I3. [IDEA] Emulator suite (Auth + Firestore) cho dev/CI.**
- Vấn đề: test/dev đang đụng project thật; login sim mong manh.
- Cách: firebase emulator cho rules test + seed cục bộ, tách khỏi `vibely-90fda`.
- Khó: trung · Rủi ro: thấp · Lợi: an toàn dữ liệu, test nhanh · Phụ thuộc: cấu hình emulator.
- Thời điểm: **NEXT**.

**I4. [IDEA] Trải nghiệm offline-first mượt hơn.**
- Vấn đề: Firestore có cache offline nhưng UX offline chưa chủ đích.
- Cách: skeleton/optimistic nhất quán + hàng đợi ghi.
- Khó: cao · Rủi ro: trung · Lợi: cảm giác nhanh.
- Thời điểm: **EXPERIMENT**.

## Nếu tiếp tục project — thứ tự ưu tiên đề xuất
1. Thêm test cho các vùng từng có bug (**SHOULD**).
2. Emulator + rules test (**SHOULD**) — an toàn dữ liệu.
3. Golden test UI cho màn LOCKED (**NEXT**).
4. Dọn nợ nhỏ (inline style, thumbnail seed) khi tiện (**NICE**).
