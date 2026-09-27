# Snapshot — Decision Log & Preferences

## Decision Log (quyết định có chủ ý — đừng tự đảo ngược)

**D1. Media lưu trên Cloudinary, không Firebase Storage.**
Bối cảnh: cần lưu ảnh/video. Chọn: Cloudinary (upload trực tiếp, unsigned preset). Vì: tránh phụ thuộc Storage/billing, CDN nhanh. Đánh đổi: một service ngoài. Đổi được sau nhưng cần migrate URL. (commit `bd4b56a`)

**D2. Automation không cần Blaze (không Cloud Functions).**
Chọn: CI GitHub Actions + Firestore-as-code (indexes + TTL native) + tool reconcile chạy Admin SDK. Vì: người dùng không muốn nâng gói trả phí. Đánh đổi: một số việc realtime (đếm) không tức thì, phải reconcile định kỳ. Đổi được nếu sau này bật Blaze. (commit `5a569ed`)

**D3. Đếm (like/comment/follower/post) denormalized + reconcile.**
Vì: đọc nhanh, không cần Function. Đánh đổi: có thể lệch → phải `reconcile.mjs`. Hệ quả: **đừng đặt count tay tuỳ tiện**, luôn reconcile.

**D4. Motion & Design system là hệ thống, không trang trí.**
Xây `AppMotion`/primitives + token `AppText`/màu ngữ nghĩa có chủ đích. Vì: nhất quán, "less but better". Hệ quả: **không thêm animation/màu/card lẻ** ngoài hệ thống.

**D5. i18n song ngữ VI/EN qua `tr('vi','en')`.**
Mọi text người dùng đi qua `tr()`. Hệ quả: thêm text mới phải qua `tr()`, giữ 2 ngôn ngữ.

**D6. Tương tác seed phải THẬT (không buff ảo).**
Người dùng chọn "tạo tương tác thật từ user seed". Hệ quả: khi cần engagement, tạo like/comment doc thật + reconcile, hoặc để 0 — không đặt số ảo.

**D7. Explore = bài của người CHƯA follow (giống Instagram).**
Không phải bug khi trống. Để có nội dung: đồ thị follow một phần / thêm author chưa follow (đã thêm `thuha.frames`, `baokhang.shots`, `ngoclan.studio`). Đừng "sửa" bằng cách bỏ điều kiện lọc.

**D8. `Post.coverUrl` fallback `thumbUrl` (nếu không rỗng) → `url`; bài ảnh để `thumbUrl` rỗng.**
Quy ước dữ liệu có chủ đích. Đừng đổi getter thành ưu tiên khác mà không xét seed.

**D9. Thao tác dữ liệu seed bằng REST API, không node firebase SDK.**
Vì SDK JS hỏng trên node v24. Đổi được nếu hạ node/sửa ESM, nhưng REST luôn chạy.

**D10. Bìa seed ép `fm=jpg` (không WebP).**
Vì WebP khó giải mã trên simulator. Quy ước dữ liệu, không phải code.

**D11. `.claude/skills/` bị gitignore nhưng skill được force-add để push.**
Bộ skill này cố ý đưa vào git (`git add -f`). Không chứa secret.

## User Preferences (bằng chứng lặp lại trong quá trình làm việc)
- **Giao tiếp tiếng Việt**; code/commit tiếng Anh. (CLAUDE.md + xuyên suốt)
- **Yêu cầu verify thật trên simulator**, không chấp nhận "code có vẻ đúng".
- **Ghét nội dung/số liệu ảo** ("buff ảo").
- **Ghét viết học thuật/dài dòng** — "ghi cái gì đáng ghi thôi", gọn.
- **Ý thức bảo mật cao** — không lộ secret vì push git công khai.
- **Tự chủ khi rõ ràng**: nhắn ngắn, kỳ vọng AI tự suy luận & làm; tự commit+push khi xong.
- **Muốn AI chủ động phát hiện & đề xuất cải tiến**, nhưng **không tự triển khai** thay đổi rủi ro.
- Cách làm việc theo giai đoạn (phase-by-phase), theo mockup.
- Thích giải thích ngắn gọn kèm thuật ngữ tiếng Anh khi cần.

## DO NOT PRESERVE (kiến thức lỗi thời — không biến thành rule)
- Giả thuyết sai đã bác bỏ: "bìa trống do memCacheWidth/WebP decode/cache poisoning" (nguyên nhân thật là `thumbUrl` rỗng). Chỉ giữ **bài học quy trình**, không giữ kết luận sai.
- Các URL bìa cũ dùng `picsum.photos`/`auto=format` — đã thay bằng `fm=jpg`.
- "Note tự tạo lại" — đã xác định KHÔNG phải bug (residue + cache offline). Đừng đi sửa.
- Chi tiết thao tác one-time (uninstall/reinstall, gỡ vimart/memento) — chỉ là tình huống, không phải quy ước.
- Mọi API key/mật khẩu cụ thể — không lưu ở bất kỳ đâu.
