# Bàn giao Trí Nghĩa — Khám phá và Tìm kiếm

## Đã hoàn thành

- `lib/features/discovers/discover_page.dart`: đầu trang gradient cam–hồng, logo, tìm kiếm, bộ lọc thể loại, Đang đọc, Sách nổi bật ba cột, Xem tất cả/Thu gọn và Gợi ý cho bạn; có trạng thái tải/rỗng/lỗi và thử lại.
- `lib/features/discovers/widgets/category_selector.dart`: Tất cả, các thể loại từ danh mục, lựa chọn đang chọn và cuộn ngang.
- `lib/features/discovers/widgets/reading_card.dart`: nhận sách và tiến độ từ ngoài, hiển thị phần trăm khi có tổng trang hoặc số trang đã đọc khi chưa biết tổng.
- `lib/features/search/search_page.dart`: tìm tên sách/tác giả, xóa từ khóa, tìm bằng bàn phím, debounce 450 ms, bỏ phản hồi cũ, xử lý lỗi và tải thêm không trùng ID.
- `lib/features/search/widgets/search_filters.dart`: mọi ngôn ngữ, Việt/Anh/Pháp/Đức/Tây Ban Nha; liên quan nhất, mới nhất, cũ nhất. Thay bộ lọc sẽ gọi lại service từ trang 1.

Cây `lib/lib` cũ đã được chuyển thành `lib/core` và `lib/features` theo phân công. Import và kiểm thử người 1 được cập nhật; đăng nhập, đăng xuất và hiệu ứng vẫn được giữ.

## Chạy và mở màn hình

Chạy `flutter pub get`, rồi `flutter run`. Vì có thay đổi assets và đường dẫn, hãy dừng phiên cũ rồi chạy lại.

Đăng nhập thử bằng `demo@example.com` / `Demo1234`. Sau đăng nhập, app mở Khám phá. Thanh điều hướng có Khám phá, Tìm kiếm, Tủ sách và Cá nhân. Tủ sách hiện chỉ hiển thị danh sách đang đọc được truyền vào; chưa có chức năng lưu/xóa sách. Đăng xuất nằm ở Cá nhân.

`DiscoverPage` nhận `displayName`, `onSearch(String)`, `onBookTap(Book)`. `searchQuery` tùy chọn được chuyển nguyên sang `onSearch` khi bấm ô tìm kiếm. `loadBooks` mặc định là `SampleBooks.load`; có thể truyền hàm khác từ người 3.

```dart
DiscoverPage(
  displayName: user.displayName,
  onSearch: (query) => openSearch(query),
  onBookTap: (book) => openDetails(book),
);

SearchPage(
  service: openLibraryService,
  initialQuery: 'Harry Potter',
  onBookTap: (book) => openDetails(book),
);
```

`MainShell` đã ghép hai trang và giữ trạng thái khi đổi tab. Bấm sách mở `BookDetailPage(book: book)` với đúng đối tượng. Người 3 đã hoàn thiện Chi tiết và chọn Phiên bản bằng API thật; nút lưu sách vẫn chờ service người 4. Xem tài liệu bàn giao người 3.

## Nguồn dữ liệu và phần hỗ trợ tối thiểu

Các model/service/widget dùng chung trong bản scaffold ban đầu còn trống. Để phần người 2 chạy được, đã bổ sung:

- `Book`: `id`, `title`, `authors`, `categories`, `firstPublishYear`, `coverId`, `coverAsset`, `coverEditionKey`. Kết quả API lấy thêm `subject` để hiển thị thể loại nếu có.
- `SampleBooks.load()`: đọc và cache danh mục `assets/data/catalog_30.json`, gồm 30 sách khớp các bìa người dùng có sẵn. Người 3 đã thay mã mẫu bằng mã tác phẩm Open Library thật, thêm giới thiệu có nhãn nguồn và metadata ấn bản. Xem `Nguoi 3 - Ban giao.md` để biết hợp đồng dữ liệu mới.
- `OpenLibraryService.searchBooks(query:, language:, sort:, page:)`: gọi API thật `https://openlibrary.org/search.json`. Mỗi trang 20 sách; trả `BookSearchResult(books, total, hasMore)`. Lỗi trả `BookSearchException.message`. Chủ sở hữu service gọi `dispose()`; `MainShell` tự quản lý service mặc định.
- `BookCover`, `BookCard`, `LoadingView`, `ErrorView`: dùng chung; bìa thật được lấy bằng Cover ID hoặc mã ấn bản. Thiếu bìa/lỗi ảnh hiện bìa thay thế có tên sách, tác giả và nhãn rõ ràng; không gán bìa của sách khác. Theo [Covers API](https://openlibrary.org/dev/docs/api/covers), `default=false` trả lỗi khi không có bìa, tránh ảnh trắng mặc định.
- Package `http`; assets trong `pubspec.yaml`; quyền mạng Android và macOS.

Ngôn ngữ dùng điều kiện `language:...` trong truy vấn, không dùng riêng tham số `lang` vốn chỉ ưu tiên ngôn ngữ. Service cách các lần gửi ít nhất 1 giây và timeout sau 15 giây. Tham khảo [Search API](https://openlibrary.org/dev/docs/api/search) và [giới hạn API](https://openlibrary.org/developers/api).

## Ghép Tủ sách của người 4

Truyền `ValueListenable<List<ReadingBook>>` vào `MainShell.readingBooks` hoặc `DiscoverPage.readingBooks`. Khi Tủ sách cập nhật notifier, giao diện cập nhật ngay. Ví dụ, từ dữ liệu thật của Tủ sách:

```dart
readingNotifier.value = savedBooks
    .where((saved) => saved.isReading)
    .map((saved) => ReadingBook(
          book: saved.book,
          pagesRead: saved.pagesRead,
          totalPages: saved.totalPages,
        ))
    .toList();
```

Đoạn trên minh họa cách ánh xạ; tên trường `savedBooks` do người 4 quyết định. Bên tạo notifier quản lý vòng đời của nó. Hiện chưa có service Tủ sách, nên app hiển thị lời nhắc chưa có sách đang đọc; không dựng tiến độ giả và không lưu dữ liệu Tủ sách trong UI. Đã kiểm thử việc nhận/cập nhật tiến độ từ notifier.

## Kiểm tra và ảnh

- Bộ kiểm thử gồm chức năng người 1, animation, model/service, 30 asset bìa, bộ lọc, debounce, phản hồi đến muộn, tải thêm không trùng, thử lại trang bị lỗi, ảnh thay thế và màn hình nhỏ 320 × 568 với chữ 150%.
- Đã gọi service thật: tìm Harry Potter với tiếng Anh, tải trang 2 và tìm Jane Austen với sắp xếp cũ nhất. Cả ba truy vấn trả 20 sách.
- [Ảnh Khám phá](screenshots/discover.png) được tạo bằng danh mục mẫu; fixture ảnh mới truyền Atomic Habits ở 208/320 trang (65%), chỉ dành cho kiểm tra bố cục. App không tự tạo lịch sử đọc này.
- [Ảnh Tìm kiếm](screenshots/search.png) dùng fixture George Orwell và bìa local để ảnh kiểm thử ổn định. Trong app, Tìm kiếm dùng API thật, không tự chuyển sang dữ liệu mẫu khi mất mạng.
- Ảnh được xuất bằng Flutter widget renderer, không phải ảnh chụp thiết bị thật.

```sh
flutter analyze
flutter test
flutter test test/auth_preview_test.dart --dart-define=CAPTURE_AUTH=true --dart-define=FLUTTER_SDK=/path/to/flutter
```

Thay `/path/to/flutter` bằng thư mục Flutter SDK. Chưa kiểm tra trên thiết bị thật. Xác thực tài khoản vẫn là bản mô phỏng đã thống nhất ở phần người 1.

## Cập nhật giao diện theo ảnh tham khảo

- Khám phá: nền kem, đầu trang cam–hồng, danh mục dạng pill, thẻ tiến độ có nút Tiếp tục đọc, sách nổi bật và gợi ý. Tiếp tục đọc mở trang chi tiết hiện có, chưa phải trình đọc ebook.
- Tìm kiếm: logo trên nền gradient, ô tìm kiếm trắng, bộ lọc hai cột (xếp dọc khi chữ lớn), thẻ sách có bìa lớn và nhãn thể loại/năm xuất bản. Chưa thêm chức năng bookmark vì service lưu sách thuộc người 4 chưa có.
- Đã cập nhật kiểm thử cho bố cục, điều hướng Tủ sách, Xem tất cả/Thu gọn, mã bìa ấn bản và bìa thay thế. `flutter analyze` sạch. Lượt toàn bộ đạt 42/43; kiểm thử còn lại cần chờ khung hình sau khi cuộn và đã sửa. Chạy lại cả 7 kiểm thử Tìm kiếm đều đạt. Tổng cộng 43 kiểm thử đã đạt qua các lượt này.
- Đã xuất và xem lại `screenshots/discover.png` và `screenshots/search.png` bằng Flutter renderer. Chưa chạy trên điện thoại thật.
