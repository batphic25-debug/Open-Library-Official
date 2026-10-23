import 'package:open_library_client/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';
import 'reset_password_page.dart';

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
    title: context.tr("Quên mật khẩu?"),
    subtitle: context.tr("Nhập email của bạn để yêu cầu đặt lại mật khẩu."),
    showBack: true,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.authService.apiClient == null)
            AuthNotice(
              context.tr(
                'Chưa hỗ trợ gửi email đặt lại mật khẩu. Mật khẩu hiện tại không thay đổi.',
              ),
            ),
          if (_error != null) AuthNotice(_error!, error: true),
          if (_sent && widget.authService.apiClient == null)
            AuthNotice(
              context.tr(
                'Chưa thể gửi email đặt lại mật khẩu. Bạn vẫn có thể đăng nhập bằng mật khẩu cũ.',
              ),
            ),
          if (_sent && widget.authService.apiClient != null)
            AuthNotice(
              context.tr(
                'Nếu tài khoản tồn tại, yêu cầu đặt lại mật khẩu đã được ghi nhận.',
              ),
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
              validator: (value) =>
                  context.trValidation(AuthService.validateEmail(value)),
              onFieldSubmitted: (_) => _send(),
              onChanged: (_) {
                if (_sent) setState(() => _sent = false);
              },
              decoration: const InputDecoration(
                hintText: 'ban@example.com',
                prefixIcon: AuthInputIcon(Icons.email_rounded),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuthButton(
            label: context.tr("Gửi yêu cầu"),
            loading: _loading,
            onPressed: _send,
          ),
          if (widget.authService.apiClient != null)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ResetPasswordPage(authService: widget.authService),
                ),
              ),
              child: Text(context.tr('Tôi đã có mã đặt lại')),
            ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(context.tr("Quay lại đăng nhập")),
          ),
        ],
      ),
    ),
  );
}
