import 'package:open_library_client/core/l10n/app_strings.dart';
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
      _notice = context.tr(
        "Đăng ký thành công! Hãy đăng nhập bằng tài khoản vừa tạo.",
      );
    });
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: context.tr("Đăng nhập"),
    subtitle: context.tr("Chào mừng trở lại với tủ sách của bạn."),
    hero: true,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice != null) AuthNotice(_notice!),
            if (_error != null) AuthNotice(_error!, error: true),
            Semantics(
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
                decoration: const InputDecoration(hintText: 'Email'),
              ),
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _password,
              label: context.tr("Mật khẩu"),
              minimal: true,
              enabled: !_loading,
              validator: (value) => value == null || value.isEmpty
                  ? context.tr("Vui lòng nhập mật khẩu")
                  : null,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 26),
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
                child: Text(context.tr("Quên mật khẩu?")),
              ),
            ),
            const SizedBox(height: 8),
            AuthButton(
              label: context.tr("Đăng nhập"),
              sweepOnPress: true,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.tr("Chưa có tài khoản?")),
                TextButton(
                  onPressed: _loading ? null : _register,
                  child: Text(context.tr("Đăng ký")),
                ),
              ],
            ),
            if (widget.authService.apiClient == null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        _email.text = AuthService.demoEmail;
                        _password.text = AuthService.demoPassword;
                      },
                icon: const Icon(Icons.auto_stories_outlined, size: 18),
                label: Text(context.tr('Điền tài khoản xem trước')),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Tài khoản chỉ dùng trong phiên này. Không nhập mật khẩu thật.',
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
