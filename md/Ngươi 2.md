# Người 2 — Trang Khám phá và Tìm kiếm

**Dự án:** Open Library Client  
**Thư mục phụ trách:** `lib/features/discovers/` và `lib/features/search/`

## 1. Công việc chính

Làm trang Khám phá để người dùng xem sách và trang Tìm kiếm để tìm theo tên sách hoặc tác giả. Dùng dữ liệu và service của người 3; phối hợp với người 5 để ghép hai trang vào app.

| File | Công việc cần làm |
|---|---|
| `lib/features/discovers/discover_page.dart` | Trang Khám phá, danh mục và danh sách sách. |
| `lib/features/discovers/widgets/category_selector.dart` | Các nút chọn thể loại sách. |
| `lib/features/discovers/widgets/reading_card.dart` | Thẻ sách đang đọc và tiến độ đọc. |
| `lib/features/search/search_page.dart` | Ô tìm kiếm, danh sách kết quả và tải thêm. |
| `lib/features/search/widgets/search_filters.dart` | Bộ lọc ngôn ngữ và lựa chọn sắp xếp. |

Các đường dẫn trên tính từ thư mục gốc `open_library_client`. Giữ tên thư mục `discovers` theo phân công của nhóm; không tạo thêm một thư mục `lib` bên trong `lib`.

## 2. Yêu cầu từng file

### `discover_page.dart`

- Hiển thị logo, lời chào và ô tìm kiếm.
- Hiển thị các thể loại và danh sách sách nổi bật từ danh mục 30 sách do người 3 cung cấp.
- Khi chọn thể loại, cập nhật danh sách sách tương ứng.
- Dùng `reading_card.dart` để hiển thị sách đang đọc từ dữ liệu tủ sách của người 4.
- Khi chưa có sách đang đọc, hiển thị lời nhắc thêm sách vào tủ.
- Khi bấm ô tìm kiếm, chuyển sang trang Tìm kiếm; nếu có từ khóa, truyền từ khóa sang.
- Khi bấm một cuốn sách, truyền đối tượng `Book` sang trang Chi tiết do người 3 phụ trách.
- Có trạng thái đang tải, danh sách rỗng và lỗi kèm nút thử lại.

### `category_selector.dart`

- Hiển thị các thể loại có trong danh mục, ví dụ Văn học, Kỳ ảo, Trinh thám và Thiếu nhi.
- Có lựa chọn Tất cả và làm nổi bật thể loại đang chọn.
- Cho phép cuộn ngang khi nhiều thể loại.
- Trả thể loại được chọn về trang Khám phá để cập nhật danh sách.

### `reading_card.dart`

- Hiển thị bìa, tên sách, tác giả và tiến độ đọc.
- Nhận sách và tiến độ từ bên ngoài; không tự lưu dữ liệu tủ sách.
- Không tự đặt tiến độ giả khi chưa có dữ liệu. Nếu chưa biết tổng số trang, có thể hiển thị số trang đã đọc thay cho phần trăm.
- Bấm thẻ để mở sách hoặc chuyển sang Tủ sách theo luồng nhóm thống nhất.

### `search_page.dart`

- Có ô nhập tên sách hoặc tác giả, nút xóa từ khóa và thao tác tìm kiếm.
- Gọi `searchBooks()` của service người 3 để lấy kết quả.
- Chờ người dùng ngừng gõ một khoảng ngắn rồi tìm, tránh gửi yêu cầu ở mỗi ký tự.
- Khi đổi từ khóa hoặc bộ lọc, tìm lại từ trang đầu; kết quả cũ không được ghi đè kết quả mới.
- Hiển thị bìa, tên sách, tác giả và năm xuất bản lần đầu nếu có.
- Dùng ảnh bìa mặc định khi thiếu hoặc tải ảnh bị lỗi.
- Có nút Tải thêm khi còn kết quả; không thêm trùng sách và không gửi nhiều yêu cầu cùng lúc.
- Bấm sách để mở trang Chi tiết với đúng đối tượng `Book`.
- Phân biệt rõ chưa nhập từ khóa, không tìm thấy sách và lỗi kết nối. Khi lỗi, có nút thử lại.

### `search_filters.dart`

- Cho chọn mọi ngôn ngữ hoặc một ngôn ngữ cụ thể theo danh sách nhóm thống nhất.
- Có lựa chọn sắp xếp như Liên quan nhất, Mới nhất và Cũ nhất.
- Trả lựa chọn về trang Tìm kiếm để gọi service với tham số tương ứng.
- Bộ lọc phải làm thay đổi kết quả, không chỉ thay màu nút.

## 3. Phối hợp với các thành viên

| Thành viên | Nội dung cần phối hợp |
|---|---|
| Người 3 | Nhận model `Book`, danh mục 30 sách, hàm `SampleBooks.load()` và `searchBooks()`; thống nhất cách mở trang Chi tiết. |
| Người 4 | Nhận sách đang đọc và tiến độ từ Tủ sách; cập nhật thẻ khi dữ liệu thay đổi. |
| Người 5 | Ghép trang Khám phá và Tìm kiếm vào `MainShell`; dùng theme, `BookCover`, `BookCard`, loading và error dùng chung. |

Người 3 quản lý `book.dart` và `open_library_service.dart`. Người 2 gọi các phần này; nếu cần thêm trường hoặc tham số, trao đổi trước. Người 5 quản lý `main.dart`, `app.dart` và `pubspec.yaml`.

## 4. Kết quả cần bàn giao

- Năm file phụ trách đã có code.
- Trang Khám phá hiển thị sách từ danh mục 30 cuốn và chọn được thể loại.
- Trang Tìm kiếm hoạt động với service, có bộ lọc và tải thêm.
- Hướng dẫn ngắn cách mở hai trang, truyền từ khóa và xử lý khi bấm sách.
- Ảnh chạy thử hai trang; ghi rõ phần nào dùng dữ liệu mẫu, phần nào dùng API và phần nào còn chờ ghép.

## 5. Kiểm tra trước khi gửi code

- [ ] Danh sách sách và bộ lọc thể loại hiển thị đúng.
- [ ] Sách đang đọc và tiến độ lấy đúng từ Tủ sách.
- [ ] Tìm được bằng tên sách và tên tác giả.
- [ ] Đổi nhanh từ khóa không làm hiện nhầm kết quả cũ.
- [ ] Đổi ngôn ngữ hoặc cách sắp xếp thì danh sách được cập nhật.
- [ ] Tải thêm hoạt động và không thêm trùng sách.
- [ ] Bấm sách mở đúng trang Chi tiết.
- [ ] Thiếu bìa hoặc lỗi ảnh thì có ảnh thay thế.
- [ ] Có thông báo khi không có kết quả hoặc mất mạng.
- [ ] Bàn phím và màn hình nhỏ không gây tràn giao diện.
- [ ] Chạy `flutter analyze` và xử lý lỗi thuộc phần mình.
