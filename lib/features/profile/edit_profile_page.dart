import 'package:open_library_client/core/l10n/app_strings.dart';

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
        throw ArgumentError("Ảnh vượt quá 2 MB. Hãy chọn ảnh nhỏ hơn.");
      }
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      await widget.settings.updateAvatar(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Đã cập nhật ảnh đại diện trên thiết bị.")),
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
      throw ArgumentError("Ảnh vượt quá 2 MB. Hãy chọn ảnh nhỏ hơn.");
    }
    return file.readAsBytes();
  }

  Future<void> _removeAvatar() async {
    try {
      await widget.settings.updateAvatar(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr("Đã khôi phục ảnh đại diện mặc định.")),
        ),
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
        SnackBar(content: Text(context.tr('Đã lưu thông tin cá nhân.'))),
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
    appBar: AppBar(title: Text(context.tr("Thông tin cá nhân"))),
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
                    _picking
                        ? context.tr("Đang chọn ảnh...")
                        : context.tr("Thay ảnh đại diện"),
                  ),
                ),
                if (widget.settings.avatarBytes != null)
                  TextButton(
                    onPressed: _picking ? null : _removeAvatar,
                    child: Text(context.tr("Dùng ảnh mặc định")),
                  ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.tr("Tên hiển thị"),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? context.tr("Vui lòng nhập tên hiển thị")
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  readOnly: !widget.authService.canChangeEmail,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      context.trValidation(AuthService.validateEmail(value)),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.trError(_error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? context.tr("Đang lưu...")
                        : context.tr("Lưu thay đổi"),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.authService.canChangeEmail
                      ? context.tr(
                          'Thay đổi tên và email sẽ mất khi khởi động lại ứng dụng.',
                        )
                      : context.tr(
                          'Email hiện chỉ xem; tên hiển thị được lưu trên tài khoản.',
                        ),
                ),
                Text(
                  context.tr(
                    "Ảnh đại diện được lưu ngay trên thiết bị khi chọn.",
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
