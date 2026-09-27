# Snapshot — Coding conventions (theo code thật)

> Nguyên tắc: **PROJECT ACTUAL CONVENTION > GENERIC CONVENTION**. Khớp code xung quanh (mật độ comment, cách đặt tên, idiom) thay vì áp best practice mặc định.

## Ngôn ngữ
- **Code, tên biến/hàm/file, commit message: tiếng Anh.** Text hiển thị cho người dùng: tiếng Việt qua `tr('vi','en')` (song ngữ). Giải thích cho người dùng: tiếng Việt.

## Đặt tên & file
- File Dart: `snake_case`. Feature-first: `features/<feature>/{data,providers,presentation}`.
- Repository: `<feature>_repository.dart` (vd `feed_repository.dart`). Provider: `<feature>_providers.dart`. Screen: `<tên>_screen.dart`. Widget con: trong `presentation/widgets/`.
- Component dùng chung: `app_<tên>.dart` với class `App<Tên>` (AppButton, AppTopBar, AppBottomSheet...). Export gọn qua `widgets/components/components.dart`.
- Token design đặt trong `abstract class App*` (AppColors, AppText, AppMotion...) — dùng qua static getter/field.

## Import
- **Import tương đối** (`../../..`) trong nội bộ feature là phổ biến; `package:snapshot/...` dùng cho core/design/models chia sẻ. Khớp file lân cận, đừng đổi kiểu import hàng loạt.

## Model
- Class immutable, `final` fields. `factory X.fromMap(Map<String,dynamic> json)` với fallback an toàn (`json['x'] as T? ?? default`). Có `toMap()`. Getter suy diễn đặt ngay trong model (vd `Post.coverUrl`, `isVideo`, `coAuthorIds`).
- **Bẫy**: dùng `?? ` với String có thể sập bẫy chuỗi rỗng — `"" ?? x` trả `""`. Khi field có thể rỗng-hợp-lệ vs thiếu, kiểm tra `isNotEmpty` thay vì chỉ null-check (xem `Post.coverUrl`).

## Repository (data layer)
- Đóng gói mọi truy cập Firestore. Trả `Stream<...>` (realtime) hoặc `Future<...>`. Dùng **transaction** khi cập nhật kèm bộ đếm (like/comment) để đếm chính xác.
- UI KHÔNG gọi Firestore trực tiếp — luôn qua repository + provider.

## Provider (state)
- Riverpod: `StreamProvider`/`FutureProvider` cho dữ liệu đọc; `Notifier` cho state có thao tác (vd `FeedController` có `loadMore`/`refresh`). Không dùng StateNotifier/ChangeNotifier.
- **Bắt provider trước `await`** nếu dùng sau đó (tránh dùng `ref` sau async gap — xem commit `fix(auth): capture providers before await`).
- Bọc UI async bằng `AsyncValueView` (đã có loading/empty/error thống nhất) thay vì tự viết mỗi màn.

## Xử lý lỗi & async
- **Không nuốt lỗi im lặng.** Thao tác async có nhánh lỗi: `loadMore` phải try/catch để không kẹt spinner (xem bug feed). Lỗi Firebase → thông điệp tiếng Việt qua `authErrorMessage`/`auth_error.dart`, không show raw code.
- Toast dùng `showAppToast` (đã thống nhất, không dùng SnackBar trực tiếp).
- Luôn `dispose()` controller/stream.

## UI
- `const` constructor ở mọi nơi có thể (perf). Widget nhỏ, tách widget con khi phức tạp.
- Dùng token (`AppText`, `AppColors`, `AppSpacing`...) — **không TextStyle/màu inline** (đã có 2 đợt sweep giảm 245→152 inline TextStyle). Ảnh mạng dùng `NetworkCover`. Chi tiết: `references/ui.md`.
- Điều hướng qua `go_router` + `Routes.*` (named routes), không hardcode path.

## Comment / doc
- Mật độ doc vừa phải (~661 `///` trong repo). Comment giải thích **tại sao**, đặc biệt cho bẫy/edge case (vd giải thích lý do fallback `coverUrl`, xử lý keychain). Không để lại code comment-out, TODO cũ, `print` thừa.

## Commit
- **Conventional Commits** tiếng Anh: `feat|fix|refactor|perf|docs|chore|style(scope): mô tả`. Body giải thích *why*. Kết thúc bằng dòng `Co-Authored-By: ...` khi được yêu cầu.
- Commit từng thay đổi logic; `flutter analyze` sạch trước khi commit; push `main`.

## Secret
- **Không hardcode** API key/mật khẩu/secret trong code hay tài liệu commit. `lib/firebase_options.dart` bị gitignore; CI dùng stub. Xem `references/anti-regression.md`.
