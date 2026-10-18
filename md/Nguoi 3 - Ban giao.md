# Bàn giao người 3 — API, Chi tiết sách và Phiên bản

## Đã triển khai

- `lib/features/books/models/book.dart`: `Book` là tác phẩm; `BookEdition` là ấn bản; `BookAuthor` chứa thông tin tác giả. Có chuyển JSON, kiểm tra mã Open Library và xử lý trường bị thiếu.
- `lib/features/books/services/open_library_service.dart`: tìm kiếm, chi tiết, phiên bản và tác giả từ API thật. Yêu cầu cách nhau ít nhất 1 giây, timeout 15 giây; lỗi mạng, HTTP và JSON trả `BookSearchException`, không biến thành kết quả rỗng. Chi tiết và phiên bản được cache trong vòng đời service; dữ liệu lỗi không ngăn thử lại.
- `lib/features/books/data/sample_books.dart`: đọc và kiểm tra đúng 30 tác phẩm không trùng mã trong `assets/data/catalog_30.json`. File `services/sample_books.dart` xuất lại lớp này để giữ tương thích import của người 2.
- `assets/data/catalog_30.json`: 30 mã tác phẩm thật, phần giới thiệu tiếng Việt do nhóm biên soạn và ảnh minh họa có sẵn. Dữ liệu ấn bản được lưu từ API, kèm URL nguồn và ngày đối chiếu.
- `book_detail_page.dart`: tải chi tiết, giới thiệu có nhãn nguồn, thể loại, metadata ấn bản, thông tin tác giả khi mở rộng, chọn phiên bản và mở Open Library bằng trình duyệt. Có tải/lỗi/thử lại, xử lý lỗi mở liên kết và chống gửi lưu nhiều lần.
- `editions_page.dart`: danh sách ấn bản, tải thêm, chống trùng mã, giữ kết quả khi tải thêm lỗi, thử lại và trả phiên bản đã chọn.

`MainShell` truyền cùng service vào Chi tiết từ Khám phá, Tìm kiếm và Tủ sách. Đã khai báo asset mới và thêm `url_launcher`; các bộ lọc, xác thực và animation hiện có được giữ.

## Cách gọi và dữ liệu trả về

```dart
final service = OpenLibraryService();
final catalog = await SampleBooks.load();
final results = await service.searchBooks(
  query: 'Harry Potter', language: 'eng',
  sort: BookSort.relevance, page: 1, limit: 20,
);
final details = await service.getBookDetails(catalog.first);
final editions = await service.getEditions(details.id, page: 1, limit: 20);
if (details.authorIds.isNotEmpty) {
  final author = await service.getAuthor(details.authorIds.first);
}
```

- `searchBooks()` trả `BookSearchResult(books, total, hasMore)`; `language: null` là mọi ngôn ngữ. `limit` từ 1 đến 100, mặc định 20; `page` bắt đầu từ 1.
- `getEditions()` trả `EditionPageResult(editions, total, hasMore)` với phân trang tương tự.
- `getBookDetails(Book)` trả `Book` kèm `selectedEdition`; `getAuthor(String)` nhận `/authors/OL…A` hoặc `OL…A`.
- Bắt `BookSearchException` và dùng `.message` cho giao diện. Tham số phân trang sai trả `ArgumentError`.
- Chủ sở hữu service gọi `dispose()`; trang mượn service từ `MainShell` không tự đóng nó.

`Book.withEdition(edition)` kiểm tra mã tác phẩm của phiên bản, rồi đổi toàn bộ metadata ấn bản và bỏ bìa minh họa cũ. Bìa, ISBN, nhà xuất bản, ngày xuất bản, ngôn ngữ và số trang luôn lấy từ cùng `selectedEdition`. Không lấy số trang hoặc ISBN của bản khác để lấp chỗ trống.

## Ghép lưu sách với người 4

**Cập nhật sau bàn giao người 4:** `MainShell` đã nối lưu cục bộ theo tài khoản, chống trùng và cấp tiến độ cho Khám phá. Xem [bàn giao người 4](Nguoi%204%20-%20Ban%20giao.md). Các đoạn dưới mô tả trạng thái tại thời điểm bàn giao người 3.

**Service Tủ sách hiện còn trống; việc lưu thật đang chờ người 4.** Đây là phần chờ tích hợp được cho phép trong mục Kết quả cần bàn giao của file phân công người 3. Giao diện hiện vô hiệu hóa nút lưu và ghi “Tính năng lưu sách chưa khả dụng.”

Truyền `Future<bool> Function(Book)` vào `MainShell.onAddToShelf` hoặc `BookDetailPage.onAddToShelf`. Hợp đồng callback:

- `true`: đã lưu thành công; giao diện báo “Đã thêm sách vào tủ.”
- `false`: tác phẩm đã có; giao diện báo “Sách đã có trong tủ.”
- Ném lỗi: giao diện báo không thể thêm, cho phép thử lại.

Người 4 cần chống trùng bằng `book.id` và lưu `book.selectedEdition.id` cùng metadata của phiên bản đã chọn. Service lưu dữ liệu phải thực hiện việc chống trùng; UI chỉ chống bấm lặp trong lúc một yêu cầu đang chờ. Đã có kiểm thử callback thành công, trùng, lỗi và bấm lặp; chưa có lưu bền vững hay đồng bộ tài khoản.

## Nguồn và dữ liệu còn thiếu

- Tham khảo [Works và Editions API](https://openlibrary.org/dev/docs/api/books), [Search API](https://openlibrary.org/dev/docs/api/search), [Authors API](https://openlibrary.org/dev/docs/api/authors), [Covers API](https://openlibrary.org/dev/docs/api/covers).
- Các phần giới thiệu trong catalog được ghi `descriptionSource: Nhóm biên soạn`. Nếu API có mô tả tác phẩm, Chi tiết dùng mô tả đó và ghi nguồn Open Library. Giới thiệu không phải toàn văn sách; không thêm nút đọc/mượn khi chưa có liên kết phù hợp.
- Ảnh local được đánh dấu `coverIsIllustration: true`, có nhãn truy cập và tooltip “Ảnh minh họa có sẵn trong dự án”. Không coi ảnh này là bìa xuất bản chính thức. Khi hiển thị ấn bản, dùng ảnh từ Covers API hoặc bìa thay thế có nhãn nếu tải lỗi.
- Dữ liệu nguồn thiếu được giữ trống và hiển thị “Chưa có dữ liệu”. Trong snapshot bàn giao: 3 ấn bản thiếu số trang, 5 thiếu ngôn ngữ, 13 thiếu ISBN-13 (có thể vẫn có ISBN-10), 1 thiếu Cover ID. Không tự bổ sung đánh giá hay thông tin xuất bản.
- [Nhật ký kiểm tra catalog](catalog-verification.json) ghi tên tác phẩm từ nguồn, mã ấn bản và trạng thái URL bìa ngày 13/10/2026. Có URL trả 404/502 tại thời điểm kiểm tra; bìa thay thế xử lý trường hợp này. Dữ liệu Open Library có thể được chỉnh sửa sau ngày đối chiếu.

## Chạy và kiểm tra

Vì có plugin và asset mới, dừng app cũ rồi chạy:

```sh
flutter pub get
flutter run
```

Đăng nhập thử `demo@example.com` / `Demo1234`, bấm sách ở Khám phá hoặc Tìm kiếm, chọn **Xem các phiên bản**, rồi chọn một bản để xem metadata thay đổi.

```sh
flutter analyze
flutter test
flutter test test/auth_preview_test.dart --dart-define=CAPTURE_AUTH=true --dart-define=FLUTTER_SDK=/path/to/flutter
flutter build web
dart run tool/verify_books.dart
```

`tool/verify_books.dart` kiểm chứng service với API thật: chi tiết Atomic Habits, 2 phiên bản, tác giả James Clear và tìm Harry Potter tiếng Anh với `limit: 3`. Đã chạy thành công; API tác giả James Clear chưa có tiểu sử trong lần kiểm tra.

Ảnh do Flutter widget renderer xuất, không phải ảnh chụp thiết bị thật. Chi tiết và Phiên bản dùng metadata catalog đã đối chiếu; môi trường test không tải mạng nên ảnh thể hiện bìa thay thế:

- [Chi tiết sách](screenshots/book-detail.png)
- [Thông tin phiên bản và nút thao tác](screenshots/book-detail-metadata.png)
- [Danh sách phiên bản](screenshots/editions.png)

Chưa kiểm tra trên thiết bị thật hoặc thao tác mở trình duyệt ngoài app trên iOS/Android. Kiểm tra cuối: `flutter analyze` không có lỗi/cảnh báo; 57 kiểm thử đạt (gồm xuất ảnh); `flutter build web` thành công. Sau chỉnh font bìa thay thế, chạy lại phân tích mã và 13 kiểm thử giao diện liên quan đều đạt; ảnh bàn giao đã xuất lại.

## Cập nhật ngày 14/10/2026 — Chi tiết và đọc sách trong app

- Chi tiết dùng nền trắng, bìa lớn có nền sáng, tên/tác giả căn giữa, nhãn thể loại, khối ngôn ngữ/ấn bản và nút lưu chuyển màu. Nút dấu trang trên thanh tiêu đề gọi cùng service lưu. Giữ số trang, ngôn ngữ và metadata thật; không tự tạo điểm đánh giá theo ảnh mẫu.
- Bìa của tác phẩm có trong Khám phá được dùng thống nhất qua `BookCover`, kể cả khi xem phiên bản khác. Nhãn ảnh minh họa vẫn nằm trong tooltip của bìa.
- Nút **Đọc sách** mở `BookReadingPage`. `OpenLibraryService.getReadingOptions()` gọi [Read API](https://openlibrary.org/dev/docs/api/read) theo OLID của phiên bản đang chọn. Chỉ nhận kết quả cùng mã tác phẩm, phân biệt đúng phiên bản và bản khác cùng tác phẩm.
- `ReadingOption` phân biệt đọc miễn phí, cần mượn, đang được mượn và quyền truy cập hạn chế. Trường hợp không có bản số hoặc lỗi mạng có thông báo/thử lại. Không dùng phần giới thiệu làm nội dung sách, không hứa mọi sách đều đọc được.
- Trên nền tảng hỗ trợ, mở nguồn bằng `url_launcher` với `LaunchMode.inAppWebView`, bật JavaScript/DOM storage để trình đọc của thư viện hoạt động. Khi không hỗ trợ, giao diện ghi rõ mở bằng trình duyệt. Web/desktop không có trình đọc nhúng riêng.
- Trình đọc cần mạng. Mượn sách có thể cần tài khoản Open Library/Internet Archive riêng; tài khoản mô phỏng trong app không dùng để mượn. Không tải sách offline, không vượt quyền truy cập, chưa tự đồng bộ vị trí đọc vào Tủ sách.

Kiểm chứng API thật bằng `dart run tool/verify_reading.dart`: The Art of Community (`OL24194264M`, tác phẩm `OL15058799W`) trả về bản khác `OL25379845M`, trạng thái `full access`, URL HTTPS của Internet Archive. Đây là kết quả tại thời điểm kiểm tra; quyền truy cập do nguồn quyết định.

Các test mới kiểm tra đường dẫn API, đúng tác phẩm/phiên bản, loại bỏ URL không hợp lệ, trạng thái mượn, không có bản đọc, lỗi mạng/thử lại, lỗi mở trình đọc và màn hình nhỏ/chữ lớn. `test/auth_preview_test.dart` xuất lại ảnh Chi tiết mới. Chưa kiểm chứng hiển thị trang đọc hoặc đăng nhập/mượn thực tế trên iOS Simulator/thiết bị Android.

Kết quả kiểm tra cập nhật: 17 test service/giao diện ban đầu đạt; sau khi bổ sung test màn hình 320 px, đã sửa dòng số trang bị tràn và chạy lại 11 test Chi tiết/Đọc sách đạt. `flutter analyze` sạch; build web và test xuất ảnh thành công. Không có test mở WebView thật trên thiết bị; các test mở trình đọc sử dụng callback thay thế.

## Cập nhật tiếp theo — Đọc văn bản offline

Phần đọc trực tuyến ở trên đã được thay bằng `OfflineBookLibrary` và `BookReadingPage` dùng asset. Mở Chi tiết rồi bấm **Đọc sách** để đọc ngay trong app, không gọi Read API hay mở trang ngoài. Với sách có bản văn đóng gói, Chi tiết cũng bỏ qua yêu cầu tải metadata trước khi mở. Trình đọc có chỉnh cỡ chữ và xem giấy phép ngay trong app. Bản văn tiếng Anh nguyên gốc và toàn bộ giấy phép được giữ trong `assets/books/`.

Các bản văn đóng gói, đối chiếu theo mã tác phẩm Open Library và [trang eBook Project Gutenberg](https://www.gutenberg.org/policy/permission):

| Sách | Mã Gutenberg |
| --- | ---: |
| Pride and Prejudice | [1342](https://www.gutenberg.org/ebooks/1342) |
| The Great Gatsby | [64317](https://www.gutenberg.org/ebooks/64317) |
| Jane Eyre | [1260](https://www.gutenberg.org/ebooks/1260) |
| Little Women | [514](https://www.gutenberg.org/ebooks/514) |
| Frankenstein | [84](https://www.gutenberg.org/ebooks/84) |
| Dracula | [345](https://www.gutenberg.org/ebooks/345) |
| The Adventures of Sherlock Holmes | [1661](https://www.gutenberg.org/ebooks/1661) |
| The Hound of the Baskervilles | [2852](https://www.gutenberg.org/ebooks/2852) |
| Alice’s Adventures in Wonderland | [11](https://www.gutenberg.org/ebooks/11) |

Các sách khác, gồm Atomic Habits và Harry Potter, chưa có bản văn được phép đóng gói và hiện thông báo rõ ràng. Bản đọc offline là văn bản của tác phẩm, không mặc định là đúng ấn bản bìa đang chọn. Phạm vi công cộng có thể khác theo quốc gia; cần kiểm tra lại quyền phân phối trước khi phát hành tại từng thị trường.

Trang Tìm kiếm có bộ lọc **Sách đọc offline**: xem cả 9 cuốn hoặc tìm theo tên/tác giả trong catalog đóng gói mà không gọi API. Vị trí cuộn và cỡ chữ được lưu trên thiết bị theo tài khoản và tác phẩm; lần mở sau tiếp tục tại vị trí đã lưu. Vị trí này độc lập với số trang nhập thủ công trong Tủ sách, và có thể lệch nhẹ nếu đổi cỡ màn hình. Kiểm tra: `flutter test`, `flutter analyze`, `flutter build web` đều đạt; bản web có đủ 9 asset sách.
