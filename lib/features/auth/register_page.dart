import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.authService});
  final AuthService authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.signUp(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(_email.text.trim().toLowerCase());
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể tạo tài khoản. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: context.tr("Tạo tài khoản"),
    subtitle: context.tr("Bắt đầu hành trình đọc sách của bạn."),
    showBack: true,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthNotice(_error!, error: true),
            AuthField(
              label: context.tr("Tên hiển thị"),
              child: TextFormField(
                controller: _name,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? context.tr("Vui lòng nhập tên hiển thị")
                    : null,
                decoration: InputDecoration(
                  hintText: context.tr("Tên của bạn"),
                  prefixIcon: AuthInputIcon(Icons.person_rounded),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: (value) =>
                    context.trValidation(AuthService.validateEmail(value)),
                decoration: const InputDecoration(
                  hintText: 'ban@example.com',
                  prefixIcon: AuthInputIcon(Icons.email_rounded),
                ),
              ),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _password,
              label: context.tr("Mật khẩu"),
              newPassword: true,
              enabled: !_loading,
              validator: (value) =>
                  context.trValidation(AuthService.validatePassword(value)),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _confirmation,
              label: context.tr("Nhập lại mật khẩu"),
              newPassword: true,
              enabled: !_loading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr("Vui lòng nhập lại mật khẩu");
                }
                if (value != _password.text) {
                  return context.tr("Hai mật khẩu không khớp");
                }
                return null;
              },
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 24),
            AuthButton(
              label: context.tr("Đăng ký"),
              loading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.tr("Đã có tài khoản?")),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(context.tr("Đăng nhập")),
                ),
              ],
            ),
            if (widget.authService.apiClient == null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Tài khoản mới chỉ dùng trong phiên này. Không nhập email hoặc mật khẩu thật.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
