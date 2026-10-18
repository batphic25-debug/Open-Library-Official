import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import 'avatar_image.dart';
import 'settings_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.authService,
    required this.settings,
    this.pickImage,
  });
  final AuthService authService;
  final SettingsService settings;
  final Future<Uint8List?> Function()? pickImage;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.authService.currentUser?.displayName,
  );
  late final _email = TextEditingController(
    text: widget.authService.currentUser?.email,
  );
  bool _saving = false;
  bool _picking = false;
  String? _error;

  Future<void> _chooseAvatar() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final bytes = await (widget.pickImage?.call() ?? _pickFromGallery());
      if (bytes == null || !mounted) return;
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw ArgumentError('Ảnh vượt quá 2 MB. Hãy chọn ảnh nhỏ hơn.');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      await widget.settings.updateAvatar(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật ảnh đại diện trên thiết bị.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ArgumentError
              ? error.message.toString()
              : 'Không thể dùng ảnh này. Hãy chọn ảnh khác.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > 2 * 1024 * 1024) {
      throw ArgumentError('Ảnh vượt quá 2 MB. Hãy chọn ảnh nhỏ hơn.');
    }
    return file.readAsBytes();
  }

  Future<void> _removeAvatar() async {
    try {
      await widget.settings.updateAvatar(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã khôi phục ảnh đại diện mặc định.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể xóa ảnh. Hãy thử lại.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.authService.updateProfile(
        displayName: _name.text,
        email: _email.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu hồ sơ trong phiên mô phỏng.')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể lưu hồ sơ. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin cá nhân')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: ListenableBuilder(
                    listenable: widget.settings,
                    builder: (context, _) => AvatarImage(
                      radius: 42,
                      bytes: widget.settings.avatarBytes,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _picking ? null : _chooseAvatar,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _picking ? 'Đang chọn ảnh...' : 'Thay ảnh đại diện',
                  ),
                ),
                if (widget.settings.avatarBytes != null)
                  TextButton(
                    onPressed: _picking ? null : _removeAvatar,
                    child: const Text('Dùng ảnh mặc định'),
                  ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Vui lòng nhập tên hiển thị'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: AuthService.validateEmail,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tài khoản mô phỏng: thay đổi tên và email sẽ mất khi khởi động lại ứng dụng.',
                ),
                const Text(
                  'Ảnh đại diện được lưu ngay trên thiết bị khi chọn.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
