import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import 'bookshelf_service.dart';
import 'models/saved_book.dart';

class ReadingProgressSheet extends StatefulWidget {
  const ReadingProgressSheet({
    super.key,
    required this.service,
    required this.saved,
  });
  final BookshelfService service;
  final SavedBook saved;
  @override
  State<ReadingProgressSheet> createState() => _ReadingProgressSheetState();
}

class _ReadingProgressSheetState extends State<ReadingProgressSheet> {
  late final _pages = TextEditingController(text: '${widget.saved.pagesRead}');
  final _form = GlobalKey<FormState>();
  late bool _completed = widget.saved.status == ReadingStatus.read;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.updateProgress(
        widget.saved.id,
        int.parse(_pages.text.trim()),
        completed: _completed,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Chưa lưu được tiến độ. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.saved.totalPages;
    final pages = int.tryParse(_pages.text.trim());
    final canComplete = total == null || pages == total;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SafeArea(
            top: false,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr("Cập nhật tiến độ"),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.saved.book.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _pages,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: context.tr("Số trang đã đọc"),
                      helperText: total == null
                          ? context.tr(
                              "Chưa có tổng số trang của phiên bản này.",
                            )
                          : context.tr("Tổng số trang: {0}", [total]),
                      prefixIcon: const Icon(Icons.auto_stories_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {
                      if (total != null &&
                          int.tryParse(_pages.text.trim()) != total) {
                        _completed = false;
                      }
                    }),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      if (number == null || number < 0) {
                        return context.tr("Nhập số nguyên từ 0 trở lên.");
                      }
                      if (total != null && number > total) {
                        return context.tr("Không được vượt quá {0} trang.", [
                          total,
                        ]);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (total != null &&
                      pages != null &&
                      pages >= 0 &&
                      pages <= total) ...[
                    LinearProgressIndicator(
                      value: pages / total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFFF554C),
                    ),
                    const SizedBox(height: 8),
                    Text(context.tr("{0}% đã đọc", [(pages * 100) ~/ total])),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr("Đánh dấu Đã đọc")),
                    subtitle: total != null && pages == total
                        ? Text(
                            context.tr("Sách sẽ tự chuyển vào Đã đọc khi lưu."),
                          )
                        : !canComplete
                        ? Text(
                            context.tr(
                              "Đọc hết số trang để đánh dấu hoàn thành.",
                            ),
                          )
                        : null,
                    value: _completed || (total != null && pages == total),
                    onChanged: _saving || !canComplete || total != null
                        ? null
                        : (value) => setState(() => _completed = value!),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.trError(_error!),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? context.tr("Đang lưu…")
                          : context.tr("Lưu tiến độ"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
