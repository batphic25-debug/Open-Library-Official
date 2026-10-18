import 'package:flutter/material.dart';

import 'bookshelf_service.dart';
import 'models/saved_book.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.service, required this.saved});
  final BookshelfService service;
  final SavedBook saved;
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late String _original = widget.service.noteFor(widget.saved.id)?.body ?? '';
  late final _text = TextEditingController(text: _original);
  bool _saving = false;
  bool _allowPop = false;
  bool _asking = false;
  String? _error;
  bool get _dirty => _text.text.trim() != _original;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Nhập ghi chú hoặc dùng nút Xóa ghi chú.');
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveNote(widget.saved.id, _text.text);
      if (!mounted) return false;
      setState(() {
        _original = _text.text.trim();
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu ghi chú.')));
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Chưa lưu được ghi chú. Nội dung vẫn được giữ để thử lại.';
        });
      }
      return false;
    }
  }

  Future<void> _leave() async {
    if (_saving || _asking) return;
    _asking = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giữ thay đổi ghi chú?'),
        content: const Text('Bạn có thay đổi chưa lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Viết tiếp'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Bỏ thay đổi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Lưu và rời trang'),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted || choice == null) return;
    if (choice == 'save' && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: const Text('Nội dung đã lưu và thay đổi đang viết sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.deleteNote(widget.saved.id);
      if (!mounted) return;
      setState(() {
        _original = '';
        _text.clear();
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa ghi chú.')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Chưa xóa được ghi chú. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Ghi chú của tôi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.saved.book.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(widget.saved.book.authorLabel),
            const SizedBox(height: 8),
            const Text(
              'Một ghi chú riêng cho mỗi sách • Lưu trên thiết bị',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _text,
              enabled: !_saving,
              minLines: 10,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nội dung ghi chú',
                alignLabelWithHint: true,
                hintText: 'Một câu văn yêu thích, một điều bạn muốn nhớ…',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Đang lưu…' : 'Lưu ghi chú'),
            ),
            if (_original.isNotEmpty)
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa ghi chú'),
              ),
          ],
        ),
      ),
    ),
  );
}
