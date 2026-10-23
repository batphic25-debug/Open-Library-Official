import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/book_cover.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import 'models/book.dart';
import 'services/open_library_service.dart';
import 'widgets/edition_metadata.dart';

class EditionsPage extends StatefulWidget {
  const EditionsPage({
    super.key,
    required this.workId,
    required this.service,
    this.selectedEditionId,
  });
  final String workId;
  final OpenLibraryService service;
  final String? selectedEditionId;
  @override
  State<EditionsPage> createState() => _EditionsPageState();
}

class _EditionsPageState extends State<EditionsPage> {
  final List<BookEdition> _editions = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.getEditions(
        widget.workId,
        page: _page + 1,
      );
      if (!mounted) return;
      final ids = _editions.map((edition) => edition.id).toSet();
      setState(() {
        _editions.addAll(
          result.editions.where((edition) => ids.add(edition.id)),
        );
        _page++;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BookSearchException
              ? error.message
              : 'Không thể tải phiên bản. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr("Phiên bản xuất bản"))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final edition in _editions)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFECECF0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BookCover(
                        book: Book(
                          id: widget.workId,
                          title: edition.title ?? context.tr("Chưa có dữ liệu"),
                          selectedEdition: edition,
                        ),
                        width: 76,
                        height: 110,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          edition.title ?? context.tr("Chưa có dữ liệu"),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EditionMetadata(edition: edition),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, edition),
                    icon: Icon(
                      edition.id == widget.selectedEditionId
                          ? Icons.check_circle_outline
                          : Icons.check,
                    ),
                    label: Text(
                      edition.id == widget.selectedEditionId
                          ? context.tr("Đang chọn")
                          : context.tr("Chọn phiên bản"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_loading)
          const LoadingView()
        else if (_error != null)
          ErrorView(message: _error!, onRetry: _load)
        else if (_editions.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              context.tr("Chưa có phiên bản xuất bản."),
              textAlign: TextAlign.center,
            ),
          )
        else if (_hasMore)
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.expand_more),
            label: Text(context.tr("Tải thêm phiên bản")),
          ),
      ],
    ),
  );
}
