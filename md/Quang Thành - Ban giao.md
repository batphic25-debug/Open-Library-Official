# Người 5 — Bàn giao

## Đã ghép

- Trang Cá nhân có avatar của tài khoản hoặc ảnh mặc định, tên/email từ tài khoản, Tủ sách, Tài khoản, Cài đặt, Trợ giúp, Giới thiệu và Đăng xuất.
- Thẻ **Tủ sách của tôi** chuyển đúng tab; bốn tab giữ trạng thái khi chuyển. Đăng xuất thay navigator nên không quay lại dữ liệu tài khoản bằng nút Back.
- Sửa tên/email và đổi mật khẩu xác thực bằng `AuthService`; lưu thành công mới báo kết quả. Các thay đổi tài khoản chỉ tồn tại trong phiên mô phỏng.
- Chọn ảnh đại diện từ thư viện hoặc khôi phục ảnh mặc định. Ảnh được lưu trên thiết bị theo mã tài khoản và hiện lại sau khi mở app.
- Cài đặt Thông báo, Ngôn ngữ, Sáng/Tối lưu theo mã tài khoản trên thiết bị. Giao diện chính đổi theo Sáng/Tối; tiếng Anh hiện áp dụng cho trang Cá nhân, Cài đặt và thanh điều hướng.
- `BookCard`, `BookCover`, `LoadingView`, `ErrorView`, theme, logo, avatar và danh mục 30 sách được ghép vào app.

## Cách thử

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d A2D9B2EF-54A2-495A-B123-FCC1BAEE784A
```

Tài khoản thử: `demo@example.com` / `Demo1234`. Ảnh kiểm tra: [Cá nhân](screenshots/profile.png), [Khám phá](screenshots/discover.png), [Tìm kiếm](screenshots/search.png), [Tủ sách](screenshots/bookshelf.png).

## Giới hạn bản mô phỏng

- Tài khoản, tên/email và mật khẩu không được lưu sau khi khởi động lại. Quên mật khẩu chưa gửi email thật.
- Ảnh đại diện lưu cục bộ, chưa đồng bộ lên máy chủ. Công tắc Thông báo chỉ lưu lựa chọn, chưa gửi thông báo đẩy.
- Tiếng Anh chưa phủ toàn bộ các trang sách. Các màn khác vẫn dùng tiếng Việt.
