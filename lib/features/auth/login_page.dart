import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});
  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.authService.signIn(
        email: _email.text,
        password: _password.text,
      );
      // The app listens to currentUser and replaces the entire auth navigator.
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể đăng nhập. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(authService: widget.authService),
      ),
    );
    if (!mounted || email == null) return;
    _email.text = email;
    _password.clear();
    setState(() {
      _error = null;
      _notice = 'Đăng ký thành công! Hãy đăng nhập bằng tài khoản vừa tạo.';
    });
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Đăng nhập',
    subtitle: 'Chào mừng trở lại với tủ sách của bạn.',
    hero: true,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice != null) AuthNotice(_notice!),
            if (_error != null) AuthNotice(_error!, error: true),
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
                  hintText: 'demo@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PasswordField(
              controller: _password,
              label: 'Mật khẩu',
              enabled: !_loading,
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập mật khẩu'
                  : null,
              onSubmitted: (_) => _login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ForgotPasswordPage(
                            authService: widget.authService,
                          ),
                        ),
                      ),
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            const SizedBox(height: 12),
            AuthButton(
              label: 'Đăng nhập',
              sweepOnPress: true,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Chưa có tài khoản?'),
                TextButton(
                  onPressed: _loading ? null : _register,
                  child: const Text('Đăng ký'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AuthNotice(
              'Bản mô phỏng • Chưa kết nối máy chủ.\n'
              'Tài khoản thử: demo@example.com\nMật khẩu: Demo1234\n'
              'Chỉ dùng thông tin thử, không dùng mật khẩu thật.',
            ),
          ],
        ),
      ),
    ),
  );
}
