import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.authService});
  final AuthService authService;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _sent = false;
    });
    try {
      await widget.authService.sendPasswordReset(email: _email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể gửi yêu cầu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Quên mật khẩu?',
    subtitle: 'Nhập email của bạn để yêu cầu đặt lại mật khẩu.',
    showBack: true,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthNotice(
            'Bản mô phỏng • Chưa gửi email thật và chưa thay đổi mật khẩu.',
          ),
          if (_error != null) AuthNotice(_error!, error: true),
          if (_sent)
            const AuthNotice(
              'Đã mô phỏng yêu cầu đặt lại mật khẩu. Không có email nào được gửi. '
              'Bạn vẫn có thể đăng nhập bằng mật khẩu cũ.',
            ),
          AuthField(
            label: 'Email',
            child: TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: AuthService.validateEmail,
              onFieldSubmitted: (_) => _send(),
              onChanged: (_) {
                if (_sent) setState(() => _sent = false);
              },
              decoration: const InputDecoration(
                hintText: 'ban@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthButton(label: 'Gửi yêu cầu', loading: _loading, onPressed: _send),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    ),
  );
}
