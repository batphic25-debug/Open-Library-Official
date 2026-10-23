# Quang thành — Trang Cá nhân, giao diện chung và ghép ứng dụng

**Dự án:** Open Library Client  
**Thư mục phụ trách:** `lib/features/profile/`, `lib/features/navigation/`, `lib/core/` và các file khởi chạy ở gốc dự án.

## 1. Công việc chính

Làm trang Cá nhân theo ảnh mẫu: nền trắng, tiêu đề lớn, thông tin người dùng, lối vào Tủ sách, các mục Tài khoản và Cài đặt, nút Đăng xuất và thanh điều hướng dưới. Tạo giao diện dùng chung và ghép các phần của bốn thành viên còn lại vào cùng ứng dụng.

| File | Công việc cần làm |
|---|---|
| `lib/features/profile/profile_page.dart` | Trang Cá nhân theo ảnh mẫu và các mục chức năng. |
| `lib/features/profile/edit_profile_page.dart` | Xem và sửa tên, email, ảnh đại diện khi chức năng tài khoản hỗ trợ. |
| `lib/features/profile/change_password_page.dart` | Biểu mẫu đổi mật khẩu và thông báo kết quả. |
| `lib/features/profile/settings_page.dart` | Lưu lựa chọn thông báo, ngôn ngữ và giao diện. |
| `lib/features/profile/about_page.dart` | Giới thiệu ứng dụng, thông tin trợ giúp cơ bản. |
| `lib/features/profile/models/user_profile.dart` | Model thông tin hiển thị của người dùng. |
| `lib/features/navigation/main_shell.dart` | Thanh điều hướng Khám phá, Tìm kiếm, Tủ sách, Cá nhân. |
| `lib/core/theme/app_theme.dart` | Màu sắc, chữ, khoảng cách và kiểu nút chung. |
| `lib/core/widgets/book_card.dart` | Thẻ sách dùng lại giữa các trang. |
| `lib/core/widgets/book_cover.dart` | Ảnh bìa, tỷ lệ thống nhất và ảnh thay thế. |
| `lib/core/widgets/loading_view.dart` | Trạng thái đang tải dùng chung. |
| `lib/core/widgets/error_view.dart` | Trạng thái lỗi và nút thử lại dùng chung. |
| `lib/main.dart`, `lib/app.dart` | Khởi chạy app, thiết lập theme và màn hình đầu tiên. |
| `pubspec.yaml` | Khai báo tài nguyên ảnh và thư viện các thành viên cần dùng. |

Đường dẫn tính từ thư mục gốc `open_library_client`. Không tạo thêm một thư mục `lib` bên trong `lib`.

## 2. Yêu cầu từng phần

### `profile_page.dart`

- Nền trắng, chữ xanh đậm/đen, điểm nhấn cam san hô; bố cục và khoảng cách giống ảnh mẫu, bo góc nhẹ ở các nhóm nội dung.
- Đầu trang có tiêu đề **Cá nhân** lớn và biểu tượng bánh răng dẫn tới Cài đặt.
- Hiển thị avatar, tên, email và nút **Sửa hồ sơ**. Dùng `assets/images/default_avatar.png` khi tài khoản chưa có ảnh. Nội dung lấy từ tài khoản hiện tại, không gắn cứng tên và email trong ảnh mẫu.
- Thẻ **Tủ sách của tôi** dẫn tới tab Tủ sách của người 4; dòng mô tả “Sách đã lưu và tiến độ đọc”.
- Nhóm **Tài khoản** gồm Thông tin cá nhân và Đổi mật khẩu.
- Nhóm **Cài đặt** gồm Thông báo với công tắc, Ngôn ngữ hiển thị giá trị hiện tại, Giao diện hiển thị chế độ hiện tại; phía dưới có Trợ giúp và Giới thiệu ứng dụng.
- Nút **Đăng xuất** viền cam ở cuối trang gọi hàm đăng xuất của người 1, sau đó trở về màn hình Login và xóa dữ liệu phiên đang hiển thị.
- Cho cuộn dọc trên màn hình nhỏ; thanh điều hướng dưới luôn dễ truy cập, không che nút Đăng xuất.

### Các trang tài khoản và cài đặt

- `edit_profile_page.dart`: hiện dữ liệu hiện tại, kiểm tra dữ liệu nhập, chỉ báo thành công khi lưu xong. Nếu service tài khoản chưa hỗ trợ cập nhật email hoặc avatar, thống nhất phạm vi với người 1 và hiển thị đúng tính năng đã làm.
- `change_password_page.dart`: nhập mật khẩu cũ, mới và xác nhận; che ký tự, kiểm tra xác nhận trùng và gọi service của người 1. Không tự nhận là đã đổi mật khẩu khi chưa có nơi lưu/xác thực thật.
- `settings_page.dart`: công tắc Thông báo, lựa chọn ngôn ngữ và Sáng/Tối phải lưu được lựa chọn và cập nhật giao diện tương ứng. Nếu chỉ làm giao diện mẫu, ghi rõ mục nào chưa có tác dụng.
- `about_page.dart`: nội dung Giới thiệu ứng dụng và Trợ giúp ngắn, có cách quay về trang Cá nhân.
- `models/user_profile.dart`: chứa mã tài khoản, tên hiển thị, email, đường dẫn ảnh đại diện nếu có; không lưu mật khẩu trong model.

### `main_shell.dart`, `app_theme.dart` và widget chung

- Thanh dưới có bốn mục **Khám phá**, **Tìm kiếm**, **Tủ sách**, **Cá nhân** cùng biểu tượng. Mục hiện tại nổi bằng màu cam như ảnh mẫu; chuyển tab giữ trạng thái hợp lý.
- Ghép trang Khám phá/Tìm kiếm của người 2, trang Chi tiết của người 3, Tủ sách của người 4, Login của người 1 và trang Cá nhân trong cùng luồng điều hướng.
- Đồng nhất màu nền trắng, chữ xanh đậm, điểm nhấn cam san hô, kiểu đường viền và độ bo góc nhẹ; dùng ảnh logo có sẵn ở những màn hình đã thống nhất. Trang Cá nhân theo mẫu không cần thêm logo ở đầu trang.
- `BookCard` và `BookCover` nhận model/dữ liệu từ ngoài; hiển thị ảnh thay thế nếu thiếu bìa hoặc tải ảnh lỗi. `LoadingView` và `ErrorView` giúp các trang hiển thị trạng thái nhất quán.
- Khai báo đúng `assets/images/`, `assets/data/` và các package mà các thành viên thực sự dùng trong `pubspec.yaml`. Không tự đổi tên thư mục hoặc model của người khác khi ghép.
- `main.dart` và `app.dart` quyết định màn hình Login hay ứng dụng chính theo trạng thái đăng nhập. Sau đăng xuất, người dùng không thể quay lại dữ liệu cá nhân bằng nút Back.

## 3. Phối hợp với các thành viên

| Thành viên | Nội dung cần phối hợp |
|---|---|
| Người 1 | Nhận thông tin tài khoản, hàm sửa hồ sơ/đổi mật khẩu/đăng xuất và trạng thái đăng nhập. |
| Người 2 | Ghép hai tab Khám phá và Tìm kiếm; thống nhất thao tác mở trang Chi tiết. |
| Người 3 | Dùng `Book`, trang Chi tiết, dữ liệu sách và đường dẫn asset/API. |
| Người 4 | Mở tab Tủ sách từ thẻ “Tủ sách của tôi”; cập nhật dữ liệu theo tài khoản sau đăng nhập/đăng xuất. |

Người 5 quản lý `main.dart`, `app.dart`, `pubspec.yaml`, theme, widget chung và thanh điều hướng. Các thành viên tự quản lý code màn hình/service của mình; thống nhất giao diện gọi trước khi ghép.

## 4. Kết quả cần bàn giao

- Các file phụ trách có code, trang Cá nhân hiển thị theo ảnh mẫu trên iPhone Simulator.
- Bốn tab hoạt động, bấm Tủ sách của tôi mở đúng tab; đăng nhập/đăng xuất chuyển màn hình đúng.
- Thông tin tài khoản lấy từ nguồn đã thống nhất; cài đặt đã làm phải có tác dụng và lưu được. Ghi rõ chức năng nào còn là bản mẫu.
- Cả dự án chạy từ thư mục `open_library_client`; bàn giao ảnh chạy thử và hướng dẫn ngắn để nhóm kiểm tra.

## 5. Kiểm tra trước khi gửi code

- [ ] Trang Cá nhân có đủ avatar, tên, email, Tủ sách, Tài khoản, Cài đặt, Trợ giúp, Giới thiệu và Đăng xuất như ảnh mẫu.
- [ ] Tên/email thay đổi theo tài khoản hiện tại; thiếu avatar có ảnh mặc định.
- [ ] Sửa hồ sơ và đổi mật khẩu thông báo đúng kết quả thực tế.
- [ ] Công tắc/lựa chọn cài đặt không chỉ đổi màu mà thực hiện phần đã cam kết.
- [ ] Thẻ Tủ sách mở đúng tab; bốn mục điều hướng chuyển trang đúng và làm nổi mục hiện tại.
- [ ] Đăng xuất không để lộ trang hoặc dữ liệu của tài khoản vừa thoát.
- [ ] Màn hình nhỏ và bàn phím mở không làm tràn hoặc che nội dung.
- [ ] Logo, bìa, avatar, dữ liệu 30 sách và package được khai báo đúng trong `pubspec.yaml`.
- [ ] Chạy `flutter pub get`, `flutter analyze` và thử toàn bộ luồng Login → Khám phá → Tìm kiếm → Chi tiết → Tủ sách → Cá nhân → Đăng xuất trên Simulator.
