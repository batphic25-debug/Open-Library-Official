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
    title: 'Tạo tài khoản',
    subtitle: 'Bắt đầu hành trình đọc sách của bạn.',
    showBack: true,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthNotice(_error!, error: true),
            AuthField(
              label: 'Tên hiển thị',
              child: TextFormField(
                controller: _name,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập tên hiển thị'
                    : null,
                decoration: const InputDecoration(
                  hintText: 'Tên của bạn',
                  prefixIcon: Icon(Icons.person_outline_rounded),
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
                validator: AuthService.validateEmail,
                decoration: const InputDecoration(
                  hintText: 'ban@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _password,
              label: 'Mật khẩu',
              newPassword: true,
              enabled: !_loading,
              validator: AuthService.validatePassword,
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _confirmation,
              label: 'Nhập lại mật khẩu',
              newPassword: true,
              enabled: !_loading,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập lại mật khẩu';
                }
                if (value != _password.text) return 'Hai mật khẩu không khớp';
                return null;
              },
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 24),
            AuthButton(
              label: 'Đăng ký',
              loading: _loading,
              onPressed: _register,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Đã có tài khoản?'),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AuthNotice(
              'Bản mô phỏng: tài khoản chỉ tồn tại đến khi khởi động lại ứng dụng. '
              'Không dùng email hoặc mật khẩu thật.',
            ),
          ],
        ),
      ),
    ),
  );
}
