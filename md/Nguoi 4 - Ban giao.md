# Bàn giao người 4 — Tủ sách, tiến độ đọc và ghi chú

## Đã hoàn thành

- Sáu file theo `nguoi4.md` đã triển khai trong `lib/features/bookshelf/`.
- Tủ sách có ba nhóm **Muốn đọc / Đang đọc / Đã đọc**, bìa thay thế khi thiếu ảnh, mở Chi tiết, chuyển trạng thái, cập nhật tiến độ, viết ghi chú và xóa sách có xác nhận.
- Trang Chi tiết gọi service thật để thêm sách. Chống trùng theo `Book.id` (tác phẩm), giữ đầy đủ metadata và phiên bản được chọn. Thêm lại tác phẩm không thay phiên bản đã lưu.
- Tiến độ thay đổi cập nhật ngay thẻ Đang đọc ở Khám phá. Chỉ tính phần trăm khi tổng số trang dương. Số trang phải là số nguyên không âm, không vượt tổng đã biết.
- Khi đọc đủ số trang, có thể đánh dấu Đã đọc. Sách chưa biết tổng số trang vẫn được đánh dấu hoàn thành.
- Một ghi chú cho mỗi tác phẩm, riêng từng tài khoản. Có lưu, sửa, mở lại và xóa; hỏi lưu/bỏ/viết tiếp khi rời trang còn thay đổi. Lỗi lưu giữ nguyên nội dung nhập.
- Đổi phiên bản bằng menu sách → **Đổi phiên bản**. Sau xác nhận, tiến độ về 0, trạng thái về Muốn đọc, tổng trang lấy từ bản mới; giữ ghi chú.
- Xóa sách đồng thời xóa ghi chú và tiến độ trong cùng lần ghi dữ liệu. Chuyển về Muốn đọc đặt số trang về 0; chuyển Đã đọc đặt số trang bằng tổng nếu có.
- Có giao diện tải, lỗi/thử lại, nhóm rỗng và nút Khám phá. Danh sách cập nhật qua notifier.

## Lưu dữ liệu và tài khoản

Dùng [Sembast](https://pub.dev/packages/sembast): file trong Application Support trên thiết bị/desktop, [sembast_web](https://pub.dev/packages/sembast_web) dùng IndexedDB trên web. Mỗi tài khoản có database riêng, snapshot có phiên bản schema và kiểm tra `userId`. Các thao tác được xếp hàng; chỉ cập nhật notifier và báo thành công sau khi ghi xong. Không tự ghi đè dữ liệu không đọc được bằng danh sách rỗng.

`SavedBook` lưu metadata `Book`, metadata phiên bản, trạng thái, số trang đã đọc, ngày thêm/cập nhật. Tổng trang và mã phiên bản lấy từ phiên bản đã lưu để tránh hai nguồn dữ liệu lệch nhau. `BookNote` lưu mã ghi chú, tài khoản, tác phẩm, nội dung và ngày tạo/cập nhật. Cả hai có JSON roundtrip.

Auth vẫn là bản mô phỏng được chọn trước đó. Mã tài khoản đăng ký mới dùng email đã chuẩn hóa thay cho số thứ tự đăng ký, tránh trùng tủ sách khi khởi động lại. Tài khoản demo giữ ID `demo-user`.

- Đăng xuất giữ dữ liệu; `MaterialApp` thay navigator theo tài khoản và đóng service cũ.
- Khi mở lại app, đăng nhập demo sẽ đọc lại tủ demo. Tài khoản tự đăng ký cần đăng ký lại cùng email vì Auth chưa lưu tài khoản/mật khẩu; ID ổn định cho phép đọc lại tủ đó.
- Đây là phân tách dữ liệu của bản mô phỏng, **không phải xác thực bảo mật**. Người biết email có thể đăng ký lại email đó trên cùng thiết bị. Khi ghép backend thật cần dùng UID do backend cấp và có chính sách chuyển dữ liệu.
- Không đồng bộ nhiều thiết bị hoặc nhiều tab trình duyệt. Xóa dữ liệu ứng dụng/trình duyệt sẽ xóa tủ sách cục bộ.

## Cách ghép service

`MainShell` đã tự tạo một service theo `authService.currentUser.id`, tải dữ liệu, nối trang Tủ sách, callback lưu ở Chi tiết và `readingBooks` ở Khám phá. Không còn phần ghép bắt buộc đang chờ người 2/3/5 cho phạm vi người 4.

```dart
final shelf = BookshelfService(userId: currentUser.id);
await shelf.loadBooks(); // Kiểm tra shelf.error để hiện nút thử lại.
final added = await shelf.addBook(book); // true: đã ghi; false: đã có.
await shelf.updateStatus(book.id, ReadingStatus.reading);
await shelf.updateProgress(book.id, 42);
await shelf.saveNote(book.id, 'Điều muốn nhớ');
await shelf.deleteNote(book.id);
await shelf.removeBook(book.id);
```

Các hàm thay đổi ném lỗi khi lưu thất bại; caller phải await và xử lý lỗi. `loadBooks()` đưa lỗi vào `error` để trang hiển thị/thử lại.

- `shelf.books`, `shelf.notes`, `shelf.bookById(id)`, `shelf.noteFor(id)` cung cấp dữ liệu hiện tại.
- `ListenableBuilder(listenable: shelf, ...)` theo dõi tủ sách/ghi chú.
- `shelf.readingBooks` là `ValueListenable<List<ReadingBook>>` cấp cho Khám phá.
- Chủ sở hữu gọi `dispose()` khi kết thúc phiên; `close()` có thể await khi cần đợi ghi và đóng database hoàn toàn.
- Có injection `openDatabase`, `MainShell.bookshelfService` và `OpenLibraryApp.bookshelfFactory` phục vụ kiểm thử. Service truyền trực tiếp vào MainShell do caller đóng.

## Kiểm tra và ảnh bàn giao

```sh
flutter analyze
flutter test
flutter build web
flutter test test/auth_preview_test.dart --dart-define=CAPTURE_AUTH=true --dart-define=FLUTTER_SDK=/path/to/flutter
```

Test mới bao phủ lưu file rồi mở lại, JSON đầy đủ, thêm trùng đồng thời, tiến độ hợp lệ/không hợp lệ, thiếu tổng trang, đổi phiên bản, ghi chú CRUD, xóa dây chuyền, tách tài khoản, lỗi ghi không thay dữ liệu đã công bố, retry sau lỗi tải. Widget test kiểm tra thêm từ Chi tiết, cập nhật sang Khám phá, giữ/bỏ ghi chú, lỗi lưu có thể thử lại, màn hình 320 px với chữ lớn và bàn phím.

Ảnh xuất từ Flutter widget renderer, dữ liệu mẫu chỉ dùng trong test; app thật không tự thêm lịch sử đọc:

- [Tủ sách](screenshots/bookshelf.png)
- [Cập nhật tiến độ](screenshots/reading-progress.png)
- [Ghi chú](screenshots/book-note.png)

`flutter analyze` không có lỗi/cảnh báo; toàn bộ 72 test đạt. Test xuất ảnh chạy riêng cũng đạt. `flutter build web` thành công; `git diff --check` sạch. Đã kiểm tra ba ảnh giao diện. Chưa chạy trên thiết bị thật/iOS Simulator; chưa kiểm tra IndexedDB bằng trình duyệt thật. Kiểm thử bền vững dùng file Sembast thật trong thư mục tạm. Auth chưa có backend, không gửi email thật.

Sau khi thêm plugin lưu trữ, dừng app cũ và chạy lại đầy đủ:

```sh
flutter pub get
flutter run
```

Tài khoản thử: `demo@example.com` / `Demo1234`.
