# Người 1 — Đăng nhập và tài khoản

**Dự án:** Open Library Client  
**Thư mục phụ trách:** `lib/features/auth/`

## 1. Công việc chính

Làm chức năng đăng nhập, đăng ký, quên mật khẩu và xử lý đăng xuất. Cung cấp phần xử lý tài khoản để người 5 ghép vào app.

| File | Công việc cần làm |
|---|---|
| `login_page.dart` | Giao diện đăng nhập và kiểm tra email, mật khẩu. |
| `register_page.dart` | Giao diện đăng ký và kiểm tra thông tin tài khoản mới. |
| `forgot_password_page.dart` | Giao diện nhập email để yêu cầu đặt lại mật khẩu. |
| `auth_service.dart` | Xử lý đăng nhập, đăng ký, đặt lại mật khẩu, đăng xuất và trạng thái tài khoản. |

## 2. Yêu cầu từng file

### `login_page.dart`

- Chuyển giao diện `LoginPage` đang nằm trong `main.dart` sang file này.
- Hiển thị logo, ô email, ô mật khẩu và nút Đăng nhập.
- Có nút hiện/ẩn mật khẩu.
- Báo lỗi khi bỏ trống hoặc nhập email sai định dạng.
- Khi bấm Đăng nhập, gọi `auth_service.dart`; hiện trạng thái chờ và tránh bấm nhiều lần.
- Chỉ chuyển sang màn hình chính khi đăng nhập thành công; nếu thất bại, hiện lỗi.
- Nối nút Đăng ký và Quên mật khẩu với hai trang tương ứng.

### `register_page.dart`

- Có ô tên hiển thị, email, mật khẩu và nhập lại mật khẩu.
- Kiểm tra trường bắt buộc, email và hai mật khẩu khớp nhau.
- Quy tắc độ dài mật khẩu cần thống nhất với nhóm hoặc backend đã chọn.
- Gọi service để tạo tài khoản; hiện trạng thái chờ, lỗi hoặc kết quả thành công.
- Sau khi đăng ký thành công, quay lại trang đăng nhập.

### `forgot_password_page.dart`

- Có ô email, nút Gửi yêu cầu và nút quay lại đăng nhập.
- Kiểm tra email trước khi gọi service.
- Hiện kết quả hoặc lỗi của yêu cầu đặt lại mật khẩu.
- Nếu dùng bản giả lập, ghi rõ đây là mô phỏng, chưa gửi email thật.

### `auth_service.dart`

- Tách phần xử lý tài khoản khỏi giao diện.
- Cung cấp các hàm để màn hình gọi, theo tên đề xuất dưới đây.
- Cập nhật trạng thái tài khoản sau khi đăng nhập hoặc đăng xuất.
- Trả thông báo lỗi rõ ràng để giao diện hiển thị.

| Hàm đề xuất | Mục đích |
|---|---|
| `signIn()` | Đăng nhập bằng email và mật khẩu. |
| `signUp()` | Tạo tài khoản. |
| `sendPasswordReset()` | Yêu cầu đặt lại mật khẩu. |
| `signOut()` | Đăng xuất và xóa trạng thái đăng nhập. |
| `currentUser` | Cung cấp thông tin tài khoản hiện tại. |

**Trước khi làm service:** nhóm cần chốt dùng tài khoản giả lập hay backend thật. Với bản giả lập, dùng tài khoản thử và thông báo rõ chức năng mô phỏng; không lưu mật khẩu thật vào file dữ liệu. Khi có backend, giữ cách gọi thống nhất để dễ ghép.

## 3. Phối hợp với người 5

- Người 5 quản lý `main.dart`, `app.dart` và `MainShell`; phối hợp để nối luồng Đăng nhập → Màn hình chính.
- Nút Đăng xuất ở trang Cá nhân gọi `signOut()`, sau đó trở về trang đăng nhập và không cho quay lại màn hình chính bằng nút Back.
- Thống nhất thông tin tài khoản cần truyền: mã tài khoản, tên hiển thị và email.
- Dùng màu, font và nút chung của nhóm. Nếu cần thêm thư viện, báo người 5 cập nhật `pubspec.yaml`.

## 4. Kết quả cần bàn giao

- Bốn file trong `lib/features/auth/` đã có code.
- Hướng dẫn ngắn cách gọi service và kết quả trả về.
- Ảnh chạy thử các trang Đăng nhập, Đăng ký và Quên mật khẩu.
- Ghi rõ phần nào đã kết nối backend, phần nào còn giả lập.

## 5. Kiểm tra trước khi gửi code

- [ ] Bỏ trống thông tin hoặc nhập email sai thì có thông báo.
- [ ] Hai mật khẩu đăng ký không khớp thì không gửi yêu cầu.
- [ ] Nhập sai tài khoản thì không vào màn hình chính.
- [ ] Đăng nhập thành công thì chuyển đúng màn hình.
- [ ] Có trạng thái chờ và xử lý lỗi khi gửi yêu cầu.
- [ ] Đăng xuất thì không quay lại được màn hình chính.
- [ ] Bàn phím không che nút; trang cuộn được trên màn hình nhỏ.
- [ ] Chạy `flutter analyze` và xử lý lỗi thuộc phần mình.
