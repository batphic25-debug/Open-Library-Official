# Người 4 — Tủ sách tiến độ đọc và ghi chú

**Dự án:** Open Library Client  
**Thư mục phụ trách:** `lib/features/bookshelf/`

## 1. Công việc chính

Làm chức năng lưu sách vào tủ cá nhân, quản lý trạng thái đọc, cập nhật tiến độ và viết ghi chú. Dữ liệu cần được giữ lại sau khi đóng và mở app. Cung cấp hàm thêm sách cho người 3 và dữ liệu đang đọc cho người 2.

| File | Công việc cần làm |
|---|---|
| `bookshelf_page.dart` | Trang Tủ sách và các nhóm trạng thái đọc. |
| `bookshelf_service.dart` | Thêm, xóa, cập nhật và lưu dữ liệu tủ sách. |
| `reading_progress_sheet.dart` | Hộp nhập và cập nhật tiến độ đọc. |
| `note_editor_page.dart` | Trang viết và sửa ghi chú của sách. |
| `models/saved_book.dart` | Model một sách đã lưu vào tủ. |
| `models/book_note.dart` | Model ghi chú của sách. |

Các đường dẫn trên nằm trong `lib/features/bookshelf/`, tính từ thư mục gốc `open_library_client`.

## 2. Yêu cầu từng file

### `bookshelf_page.dart`

- Hiển thị ba nhóm: Muốn đọc, Đang đọc và Đã đọc.
- Mỗi sách có bìa, tên, tác giả và trạng thái đọc; sách đang đọc có thêm tiến độ.
- Dùng ảnh thay thế khi sách thiếu bìa hoặc tải ảnh bị lỗi.
- Cho chuyển trạng thái, cập nhật tiến độ, mở ghi chú và xóa sách khỏi tủ.
- Bấm sách để mở trang Chi tiết do người 3 phụ trách.
- Khi nhóm chưa có sách, hiển thị thông báo và nút chuyển sang Khám phá hoặc Tìm kiếm.
- Có trạng thái tải, lỗi và thử lại khi đọc dữ liệu tủ sách.
- Cập nhật danh sách khi người dùng thêm sách hoặc sửa dữ liệu ở màn hình khác.

### `bookshelf_service.dart`

- Cung cấp hàm thêm sách từ trang Chi tiết và các nút lưu sách được nhóm thống nhất.
- Dùng mã tác phẩm làm khóa để tránh lưu trùng cùng một sách. Lưu thêm mã phiên bản nếu cần giữ đúng bản xuất bản.
- Cung cấp hàm lấy danh sách, chuyển trạng thái, cập nhật tiến độ, lưu ghi chú và xóa sách.
- Lưu dữ liệu bền vững theo phương án nhóm chọn: lưu trên thiết bị hoặc backend. Không chỉ giữ danh sách trong bộ nhớ.
- Báo lỗi nếu lưu thất bại; chỉ thông báo thành công khi thao tác lưu đã hoàn tất.
- Cung cấp dữ liệu đang đọc cho người 2 và thông báo khi dữ liệu thay đổi.
- Khi dùng nhiều tài khoản, tách dữ liệu theo mã tài khoản; đăng xuất không được làm mất dữ liệu đã lưu hoặc lộ tủ sách của tài khoản trước.

| Hàm đề xuất | Mục đích |
|---|---|
| `loadBooks()` | Đọc danh sách sách đã lưu của tài khoản hiện tại. |
| `addBook()` | Thêm sách và kiểm tra trùng. |
| `removeBook()` | Xóa sách khỏi tủ. |
| `updateStatus()` | Chuyển trạng thái đọc. |
| `updateProgress()` | Lưu tiến độ đọc. |
| `saveNote()` | Tạo hoặc cập nhật ghi chú. |
| `deleteNote()` | Xóa ghi chú. |

Tên hàm và kiểu kết quả cần thống nhất với người 2 và người 3 trước khi ghép. Phương án lưu dữ liệu và thư viện cần dùng được thống nhất với người 5.

### `reading_progress_sheet.dart`

- Hiển thị tên sách, số trang đã đọc và tổng số trang nếu có.
- Cho nhập số trang đã đọc và bấm Lưu.
- Không chấp nhận giá trị âm hoặc lớn hơn tổng số trang đã biết.
- Khi biết tổng số trang lớn hơn 0, tính phần trăm từ số trang đã đọc chia cho tổng số trang.
- Nếu chưa biết tổng số trang, chỉ hiện số trang đã đọc; không chia cho 0 hoặc tự tạo phần trăm.
- Khi đọc hết số trang đã biết, cho chuyển sang Đã đọc. Người dùng vẫn có thể đánh dấu hoàn thành khi chưa biết tổng số trang.
- Khi lưu thành công, cập nhật cả Tủ sách và thẻ Đang đọc ở trang Khám phá.

### `note_editor_page.dart`

- Hiển thị tên sách và vùng nhập ghi chú.
- Cho tạo, sửa, lưu và xóa ghi chú.
- Ghi chú cần gắn đúng sách và đúng tài khoản.
- Hiển thị nội dung đã lưu khi mở lại trang.
- Khi rời trang mà còn thay đổi chưa lưu, hỏi người dùng muốn giữ hay bỏ thay đổi.
- Báo lỗi nếu lưu thất bại; trang cuộn được khi nội dung dài hoặc bàn phím mở.

### `models/saved_book.dart`

- Lưu mã tài khoản, mã tác phẩm và thông tin sách cần hiển thị từ model `Book` của người 3.
- Lưu mã phiên bản được chọn, trạng thái đọc, số trang đã đọc và tổng số trang nếu có.
- Lưu ngày thêm và ngày cập nhật.
- Có phần chuyển đổi dữ liệu để lưu và đọc lại.
- Khi đổi phiên bản, kiểm tra lại tổng số trang và tiến độ; không giữ phần trăm từ phiên bản cũ một cách tự động.

### `models/book_note.dart`

- Lưu mã ghi chú, mã tài khoản, mã sách, nội dung, ngày tạo và ngày cập nhật.
- Có phần chuyển đổi dữ liệu để lưu và đọc lại.
- Thống nhất dùng một ghi chú cho mỗi sách hay nhiều ghi chú; giao diện và service phải dùng cùng quy tắc.

## 3. Phối hợp với các thành viên

| Thành viên | Nội dung cần phối hợp |
|---|---|
| Người 1 | Nhận mã tài khoản hiện tại và xử lý thay đổi tài khoản hoặc đăng xuất. |
| Người 2 | Cung cấp sách đang đọc và tiến độ cho trang Khám phá; nhận thao tác mở Tủ sách. |
| Người 3 | Dùng model `Book`; nối nút thêm vào tủ ở Chi tiết và giữ thông tin phiên bản. |
| Người 5 | Ghép trang Tủ sách vào `MainShell`; dùng theme, widget bìa và khai báo thư viện lưu dữ liệu. |

Người 4 quản lý model và service tủ sách. Người 3 quản lý model `Book`; khi cần thêm trường, trao đổi trước. Người 5 quản lý `main.dart`, `app.dart` và `pubspec.yaml`.

## 4. Kết quả cần bàn giao

- Sáu file phụ trách đã có code.
- Thêm, xóa, chuyển trạng thái, cập nhật tiến độ và lưu ghi chú hoạt động.
- Dữ liệu vẫn còn sau khi đóng và mở app.
- Hướng dẫn ngắn cách gọi service, xác định tài khoản và nhận thông báo thay đổi dữ liệu.
- Ảnh chạy thử; ghi rõ phần còn chờ ghép với các thành viên khác.

## 5. Kiểm tra trước khi gửi code

- [ ] Thêm sách từ Chi tiết thì xuất hiện đúng trong Tủ sách.
- [ ] Thêm lại cùng sách không tạo bản ghi trùng.
- [ ] Chuyển giữa Muốn đọc, Đang đọc và Đã đọc hoạt động.
- [ ] Không chấp nhận tiến độ âm hoặc vượt tổng số trang đã biết.
- [ ] Sách thiếu tổng số trang không gây lỗi tính phần trăm.
- [ ] Tiến độ ở Tủ sách và Khám phá được cập nhật cùng nhau.
- [ ] Ghi chú được lưu, sửa, xóa và mở lại đúng sách.
- [ ] Đóng và mở app không làm mất dữ liệu.
- [ ] Đổi tài khoản không hiển thị dữ liệu của tài khoản trước.
- [ ] Xóa sách xử lý ghi chú liên quan theo quy tắc nhóm thống nhất.
- [ ] Tủ sách rỗng hoặc lỗi lưu có thông báo rõ ràng.
- [ ] Giao diện không tràn khi tên sách hoặc ghi chú dài.
- [ ] Chạy `flutter analyze` và các test liên quan; xử lý lỗi thuộc phần mình.
