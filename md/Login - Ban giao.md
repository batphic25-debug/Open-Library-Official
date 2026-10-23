# Bàn giao người 1 — Đăng nhập và tài khoản

## Phạm vi đã hoàn thành

- Đăng nhập: kiểm tra email, mật khẩu; hiện/ẩn mật khẩu; báo lỗi; trạng thái chờ và chặn gửi lặp.
- Đăng ký: tên hiển thị, email, mật khẩu từ 8 ký tự, xác nhận mật khẩu; chặn email trùng; quay lại đăng nhập và điền email sau khi thành công.
- Quên mật khẩu: kiểm tra email, gọi service, thông báo rõ chỉ mô phỏng và không gửi email thật.
- Đăng xuất: xóa `currentUser`, hủy lịch sử điều hướng của phiên đăng nhập; nút Back không mở lại trang được bảo vệ.
- Giao diện tiếng Việt theo mẫu: nền cam–hồng, logo có sẵn, hình sách, trường nhập bo góc, nút chuyển màu.
- Trang cuộn được; đã kiểm thử ở 320 × 568, bàn phím cao 240 và cỡ chữ 150%.

Bốn file chính nằm tại `lib/features/auth/`; cây thư mục đã được chuẩn hóa khi ghép phần người 2. `auth_widgets.dart` chia sẻ bố cục, trường mật khẩu, nút và thông báo giữa ba trang. Không thêm dependency.

## Chế độ mô phỏng đã thống nhất

| Thông tin | Giá trị |
|---|---|
| Email thử | `demo@example.com` |
| Mật khẩu thử | `Demo1234` |
| Tên hiển thị | Nghĩa |
| Mật khẩu đăng ký | Ít nhất 8 ký tự; không tự cắt khoảng trắng trong mật khẩu |
| Email | Cắt khoảng trắng đầu/cuối, không phân biệt hoa/thường |

Đây là tài khoản thử của ứng dụng, không phải xác thực với `openlibrary.org`. Chưa kết nối backend nào. Tài khoản đăng ký và phiên đăng nhập chỉ nằm trong bộ nhớ, mất khi khởi động lại ứng dụng. Không ghi mật khẩu vào file, thiết lập hoặc log. Chỉ nhập thông tin thử.

Yêu cầu đặt lại mật khẩu không gửi email và không đổi mật khẩu. Người dùng vẫn đăng nhập bằng mật khẩu cũ. Service trả cùng kết quả mô phỏng cho mọi email đúng định dạng.

## Giao diện service cho người 5

`AuthService` kế thừa `ChangeNotifier`. Dùng một instance chung trong vòng đời ứng dụng; không tạo service riêng cho từng trang.

| API | Kết quả |
|---|---|
| `signIn(email: ..., password: ...)` | `Future<UserProfile>`; cập nhật `currentUser` và thông báo listener |
| `signUp(displayName: ..., email: ..., password: ...)` | `Future<void>`; tạo tài khoản, không tự đăng nhập |
| `sendPasswordReset(email: ...)` | `Future<void>`; chỉ mô phỏng |
| `signOut()` | `Future<void>`; xóa phiên và thông báo listener |
| `currentUser` | `UserProfile?`; `null` khi chưa đăng nhập |

`UserProfile` chứa `id`, `displayName`, `email`; không chứa mật khẩu. Lỗi nghiệp vụ được trả bằng `AuthException.message`. Các trang cũng xử lý lỗi ngoài dự kiến và mở lại nút để thử lại.

```dart
final auth = AuthService();
try {
  final user = await auth.signIn(
    email: AuthService.demoEmail,
    password: AuthService.demoPassword,
  );
  // Dùng user.id, user.displayName và user.email cho phần tài khoản.
} on AuthException catch (error) {
  // Hiển thị error.message.
}
await auth.signOut();
auth.dispose();
```

`main.dart` khởi chạy `OpenLibraryApp` trong `app.dart`. App sở hữu service mặc định; có thể truyền `OpenLibraryApp(authService: auth)` để dùng instance chung khác. Khi truyền service từ bên ngoài, bên tạo service chịu trách nhiệm `dispose()`.

App theo dõi service và thay navigator khi đổi trạng thái đăng nhập. Người 5 giữ cơ chế này khi ghép `MainShell` đầy đủ. `MainShell` đã ghép Khám phá và Tìm kiếm của người 2; trang Cá nhân vẫn cung cấp tài khoản và đăng xuất. Xem tài liệu bàn giao người 2 cho phần ghép hiện tại. Gọi `await authService.signOut()` từ nút Đăng xuất; không cần tự push trang đăng nhập.

Logo khai báo trong `pubspec.yaml`: `assets/images/logo.png`. Màu dùng chung đặt tại `lib/core/theme/app_theme.dart`.

## Kiểm tra và ảnh bàn giao

Hình sách ở trang đăng nhập lật liên tục theo chu kỳ 5 giây, nghỉ nhẹ giữa các lần lật. Ticker tạm ngừng khi trang bị ẩn. Các nút chính Đăng nhập, Đăng ký và Gửi yêu cầu thu nhẹ khi nhấn, đổi ánh sáng và bóng đổ, rồi trở về khi thả hoặc hủy thao tác. Nút Đăng nhập có thêm dải màu sáng quét từ trái sang phải trong 350 ms mỗi lần kích hoạt, tiếp tục chạy khi nút chuyển sang trạng thái chờ và không trì hoãn yêu cầu đăng nhập. Chuyển sang trạng thái chờ bằng hiệu ứng mờ dần. Cài đặt giảm chuyển động của thiết bị tắt lật sách và chuyển động của nút; phản hồi màu và tiêu điểm bàn phím vẫn được giữ. Không thêm thư viện.

- `flutter analyze`: không có lỗi hoặc cảnh báo.
- `flutter test`: 22 kiểm thử chức năng và hiệu ứng; kiểm thử xuất ảnh chỉ chạy khi bật `CAPTURE_AUTH`.
- Kiểm thử service bao gồm sai tài khoản, đăng ký trùng, kiểm tra dữ liệu trực tiếp, đăng xuất và mất dữ liệu khi tạo phiên ứng dụng mới.
- Kiểm thử giao diện bao gồm lỗi nhập liệu, hiện mật khẩu, chặn gửi lặp, lỗi service, đăng ký rồi đăng nhập, quên mật khẩu, Back sau đăng xuất và màn hình nhỏ.

Ảnh dưới đây do Flutter widget renderer xuất ở kích thước 430 × 1100, tỷ lệ điểm ảnh 2. Đây không phải ảnh chụp thiết bị thật. Font Roboto và Material Icons được nạp từ Flutter SDK khi xuất ảnh.

- [Đăng nhập](screenshots/login.png)
- [Đăng ký](screenshots/register.png)
- [Quên mật khẩu](screenshots/forgot-password.png)

Xuất lại ảnh, thay `/path/to/flutter` bằng thư mục Flutter SDK:

```sh
flutter test test/auth_preview_test.dart --dart-define=CAPTURE_AUTH=true --dart-define=FLUTTER_SDK=/path/to/flutter
```

Chạy ứng dụng: `flutter run`.

Chưa kiểm tra trên thiết bị thật. Khi có backend, thay phần xử lý mô phỏng trong service, giữ API phía trên và cập nhật thông báo giao diện; không sử dụng kho tài khoản trong bộ nhớ cho sản phẩm thật.
