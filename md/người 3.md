# Người 3 — Dữ liệu API và Chi tiết sách

**Dự án:** Open Library Client  
**Thư mục phụ trách:** `lib/features/books/` và `assets/data/`

## 1. Công việc chính

Chuẩn bị dữ liệu 30 sách, làm service kết nối Open Library, trang Chi tiết sách và trang Phiên bản. Cung cấp dữ liệu và hàm tìm kiếm cho người 2; nối chức năng thêm sách vào tủ với người 4.

| File | Công việc cần làm |
|---|---|
| `lib/features/books/models/book.dart` | Model sách và phiên bản dùng chung cho nhóm. |
| `lib/features/books/services/open_library_service.dart` | Gọi API tìm sách, lấy chi tiết, phiên bản và thông tin tác giả. |
| `lib/features/books/data/sample_books.dart` | Đọc danh mục 30 sách từ file JSON. |
| `assets/data/catalog_30.json` | Lưu thông tin 30 sách đã chọn. |
| `lib/features/books/book_detail_page.dart` | Giao diện thông tin chi tiết của một cuốn sách. |
| `lib/features/books/editions_page.dart` | Giao diện chọn và xem các phiên bản xuất bản. |

Các đường dẫn tính từ thư mục gốc `open_library_client`. Trang Tìm kiếm và bộ lọc giao diện thuộc người 2; người 3 cung cấp service để các trang đó gọi.

## 2. Yêu cầu từng file

### `models/book.dart`

- Tạo model `Book` chứa mã tác phẩm, tên sách, danh sách tác giả, thể loại, giới thiệu và năm xuất bản lần đầu nếu có.
- Tạo model phiên bản chứa mã phiên bản, tên phiên bản, ISBN, nhà xuất bản, ngày xuất bản, số trang, ngôn ngữ và đường dẫn bìa.
- Viết phần chuyển dữ liệu JSON thành đối tượng để các trang dùng thống nhất.
- Phân biệt tác phẩm và phiên bản: cùng một tác phẩm có thể có nhiều bản dịch hoặc lần xuất bản.
- Bìa, ISBN, số trang, nhà xuất bản và ngôn ngữ phải thuộc cùng phiên bản được chọn.
- Trường nguồn không có thì giữ trống; giao diện hiển thị “Chưa có dữ liệu”.

### `services/open_library_service.dart`

- Cung cấp hàm tìm kiếm theo tên sách hoặc tác giả cho người 2.
- Nhận tham số ngôn ngữ, cách sắp xếp, số trang kết quả và số lượng sách mỗi lần tải.
- Cung cấp hàm lấy mô tả tác phẩm và danh sách phiên bản.
- Cung cấp thông tin tác giả khi dữ liệu nguồn có; không tự bịa tiểu sử.
- Trả kết quả và lỗi rõ ràng; không biến lỗi kết nối thành danh sách rỗng thành công.
- Xử lý thời gian chờ và hạn chế gửi yêu cầu liên tục. Có thể tái sử dụng dữ liệu chi tiết đã tải trong phiên làm việc.

| Hàm dùng chung | Mục đích |
|---|---|
| `searchBooks()` | Tìm sách, lọc, sắp xếp và phân trang kết quả. |
| `getBookDetails()` | Lấy thông tin chi tiết cho một `Book`. |
| `getEditions()` | Lấy các phiên bản của tác phẩm. |
| `getAuthor()` | Lấy thông tin tác giả theo mã tác giả. |

Thống nhất tham số và kiểu kết quả với người 2 trước khi ghép code. Nếu dùng gói code đã chuẩn bị, giữ tên hàm và model nhất quán với gói đó.

### `data/sample_books.dart`

- Cung cấp `SampleBooks.load()` để đọc `assets/data/catalog_30.json` và trả danh sách `Book`.
- Cho người 2 dùng danh sách này trên trang Khám phá, không cần gọi lại API cho từng cuốn khi mở trang.
- Báo lỗi nếu file thiếu hoặc dữ liệu sai định dạng.

### `assets/data/catalog_30.json`

- Chuẩn bị đúng 30 tác phẩm đã chọn, không trùng mã tác phẩm.
- Mỗi sách có tên, tác giả, thể loại, giới thiệu, mã tác phẩm và thông tin phiên bản được chọn.
- Kiểm tra đường dẫn bìa và liên kết hồ sơ Open Library.
- Phân biệt giới thiệu do nhóm viết với mô tả lấy từ nguồn.
- Nếu dùng bìa tự thiết kế của nhóm, ghi rõ đó là ảnh minh họa và thống nhất đường dẫn với người 5; không coi đó là bìa xuất bản chính thức.
- Không tự bổ sung số trang, ISBN hoặc đánh giá khi chưa có dữ liệu xác minh.

### `book_detail_page.dart`

- Nhận đối tượng `Book` từ trang Khám phá, Tìm kiếm hoặc Tủ sách.
- Hiển thị bìa, tên sách, tác giả, thể loại và phần giới thiệu.
- Hiển thị thông tin phiên bản: ISBN, nhà xuất bản, ngày xuất bản, ngôn ngữ và số trang nếu có.
- Dùng ảnh thay thế khi bìa thiếu hoặc tải lỗi.
- Có nút xem Phiên bản, thêm vào Tủ sách và mở hồ sơ Open Library.
- Nút thêm vào Tủ sách gọi service của người 4; thông báo khi thêm thành công hoặc sách đã có.
- Có trạng thái tải, lỗi và thử lại. Trang cuộn được khi mô tả dài.
- Phần giới thiệu không phải toàn văn sách. Chỉ thêm lựa chọn đọc hoặc mượn nếu nguồn có liên kết phù hợp; không tạo nút đọc giả.

### `editions_page.dart`

- Nhận mã tác phẩm và gọi `getEditions()`.
- Hiển thị bìa, tên phiên bản, ngôn ngữ, nhà xuất bản, ngày xuất bản, ISBN và số trang nếu có.
- Cho chọn một phiên bản và trả lựa chọn về trang Chi tiết.
- Khi đổi phiên bản, cập nhật đồng bộ bìa và các trường liên quan.
- Có tải thêm khi còn phiên bản, trạng thái rỗng và xử lý lỗi.

## 3. Phối hợp với các thành viên

| Thành viên | Nội dung cần phối hợp |
|---|---|
| Người 2 | Cung cấp `Book`, danh mục 30 sách và `searchBooks()`; thống nhất cách truyền sách sang Chi tiết. |
| Người 4 | Nối thêm sách vào tủ; dùng mã tác phẩm để tránh trùng và lưu mã phiên bản khi cần giữ đúng bản. |
| Người 5 | Dùng theme, ảnh thay thế và widget bìa chung; nhờ khai báo assets, thư viện cần thiết và ghép điều hướng. |

Người 3 quản lý model và service sách. Khi thay đổi cấu trúc dữ liệu, báo người 2 và người 4 để sửa phần sử dụng. Người 5 quản lý `main.dart`, `app.dart` và `pubspec.yaml`.

## 4. Kết quả cần bàn giao

- Sáu file phụ trách có dữ liệu hoặc code hoạt động.
- Danh mục 30 sách dùng được trên trang Khám phá.
- Service tìm kiếm và lấy chi tiết dùng được bởi các thành viên khác.
- Trang Chi tiết và Phiên bản chạy được; nút thêm vào tủ đã nối hoặc ghi rõ đang chờ service người 4.
- Hướng dẫn ngắn cách gọi hàm, truyền `Book` và xử lý kết quả hoặc lỗi.
- Ảnh chạy thử; ghi rõ dữ liệu còn thiếu và phần chưa kiểm tra được.

## 5. Kiểm tra trước khi gửi code

- [ ] Danh mục có đúng 30 tác phẩm và không trùng mã.
- [ ] JSON được đọc đúng thành danh sách `Book`.
- [ ] Service tìm được bằng tên sách và tác giả.
- [ ] Bộ lọc, sắp xếp và phân trang trả kết quả phù hợp.
- [ ] Bấm sách mở đúng thông tin chi tiết.
- [ ] Bìa và thông tin xuất bản thuộc cùng phiên bản.
- [ ] Chọn phiên bản khác cập nhật đúng dữ liệu.
- [ ] Thiếu trường hoặc ảnh lỗi không làm app dừng.
- [ ] Lỗi mạng có thông báo và thao tác thử lại.
- [ ] Thêm sách vào tủ hoạt động, không tạo bản ghi trùng.
- [ ] Giao diện không tràn khi tên sách hoặc mô tả dài.
- [ ] Chạy `flutter analyze` và các test liên quan; xử lý lỗi thuộc phần mình.
