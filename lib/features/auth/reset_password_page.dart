import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'auth_service.dart';
import 'auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.authService.resetPassword(
        token: _token.text,
        newPassword: _password.text,
      );
      if (mounted) setState(() => _done = true);
    } on AuthException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể đặt lại mật khẩu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: context.tr('Đặt lại mật khẩu'),
    subtitle: context.tr('Nhập mã đặt lại và mật khẩu mới.'),
    showBack: true,
    child: _done
        ? Column(
            children: [
              AuthNotice(context.tr('Mật khẩu đã đổi. Hãy đăng nhập lại.')),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text(context.tr('Quay lại đăng nhập')),
              ),
            ],
          )
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) AuthNotice(_error!, error: true),
                AuthField(
                  label: context.tr('Mã đặt lại'),
                  child: TextFormField(
                    controller: _token,
                    autocorrect: false,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? context.tr('Vui lòng nhập mã đặt lại.')
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                PasswordField(
                  controller: _password,
                  label: context.tr('Mật khẩu mới'),
                  newPassword: true,
                  validator: (value) =>
                      context.trValidation(AuthService.validatePassword(value)),
                ),
                const SizedBox(height: 18),
                PasswordField(
                  controller: _confirmation,
                  label: context.tr('Nhập lại mật khẩu mới'),
                  newPassword: true,
                  validator: (value) => value == _password.text
                      ? null
                      : context.tr('Hai mật khẩu không khớp'),
                ),
                const SizedBox(height: 24),
                AuthButton(
                  label: context.tr('Đặt lại mật khẩu'),
                  loading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
  );
}
