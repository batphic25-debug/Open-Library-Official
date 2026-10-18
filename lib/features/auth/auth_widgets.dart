import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.hero = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Phần đầu và thanh trạng thái dùng chung nền chuyển màu.
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle.light,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.gradient,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                32,
                                hero ? 50 : 44,
                                32,
                                hero ? 12 : 28,
                              ),
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/logo.png',
                                    height: hero ? 94 : 72,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Open Library',
                                  ),
                                  if (hero) ...[
                                    const SizedBox(height: 16),
                                    const SizedBox(
                                      height: 138,
                                      width: 240,
                                      child: BookIllustration(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (showBack)
                              Positioned(
                                top: 4,
                                left: 8,
                                child: BackButton(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          child,
                        ],
                      ),
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
}

class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Semantics(label: label, child: child),
    ],
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.newPassword = false,
    this.onSubmitted,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => AuthField(
    label: widget.label,
    child: TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.newPassword ? 'Ít nhất 8 ký tự' : 'Nhập mật khẩu',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: widget.enabled
              ? () => setState(() => _obscure = !_obscure)
              : null,
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
  );
}

class AuthButton extends StatefulWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.sweepOnPress = false,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final bool sweepOnPress;

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
      _sweep.value = 1;
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _activate() {
    if (widget.sweepOnPress && !MediaQuery.disableAnimationsOf(context)) {
      _sweep.forward(from: 0);
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 140);
    return FilledButton(
      onPressed: widget.loading ? null : _activate,
      clipBehavior: Clip.none,
      style:
          FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ).copyWith(
            animationDuration: duration,
            backgroundBuilder: (context, states, child) {
              final pressed =
                  !widget.loading && states.contains(WidgetState.pressed);
              final focused =
                  !widget.loading && states.contains(WidgetState.focused);
              final highlighted =
                  pressed ||
                  focused ||
                  (!widget.loading && states.contains(WidgetState.hovered));
              return AnimatedScale(
                scale: pressed && !reduceMotion ? 0.97 : 1,
                duration: duration,
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradient,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: focused ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(
                          alpha: highlighted ? 0.22 : 0.12,
                        ),
                        blurRadius: pressed ? 12 : 24,
                        offset: Offset(0, pressed ? 3 : 8),
                      ),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: highlighted ? 0.12 : 0,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CustomPaint(
                    foregroundPainter: widget.sweepOnPress
                        ? _ButtonSweepPainter(_sweep)
                        : null,
                    child: child,
                  ),
                ),
              );
            },
          ),
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: widget.loading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                  semanticsLabel: 'Đang xử lý',
                ),
              )
            : Row(
                key: const ValueKey('label'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
      ),
    );
  }
}

class _ButtonSweepPainter extends CustomPainter {
  _ButtonSweepPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value <= 0 || animation.value >= 1) return;
    final width = size.width * 0.38;
    final x = -width + (size.width + width * 2) * animation.value;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
    );
    canvas.translate(x, 0);
    canvas.skew(-0.3, 0);
    final band = Rect.fromLTWH(-width / 2, 0, width, size.height);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x00FFD6A0),
            Color(0x44FFD6A0),
            Color(0x88FFF4DA),
            Color(0x44FFB7DF),
            Color(0x00FFB7DF),
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ButtonSweepPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFE9EB) : const Color(0xFFFFF0E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? const Color(0xFFAB1436) : AppTheme.muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ),
  );
}

class BookIllustration extends StatefulWidget {
  const BookIllustration({super.key});

  @override
  State<BookIllustration> createState() => _BookIllustrationState();
}

class _BookIllustrationState extends State<BookIllustration>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _BookPainter(_controller)));
}

class _BookPainter extends CustomPainter {
  _BookPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 138);
    canvas.drawOval(
      const Rect.fromLTWH(27, 0, 186, 138),
      Paint()..color = const Color(0xFFFF9952),
    );
    final cover = Path()
      ..moveTo(30, 51)
      ..lineTo(211, 51)
      ..lineTo(220, 124)
      ..quadraticBezierTo(220, 130, 212, 130)
      ..lineTo(25, 130)
      ..quadraticBezierTo(19, 130, 21, 122)
      ..close();
    canvas.drawPath(
      cover,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFCB3B16), Color(0xFFA21755)],
        ).createShader(const Rect.fromLTWH(20, 50, 200, 80)),
    );
    final pages = Path()
      ..moveTo(43, 35)
      ..quadraticBezierTo(33, 34, 32, 46)
      ..lineTo(38, 108)
      ..quadraticBezierTo(38, 116, 47, 117)
      ..lineTo(119, 122)
      ..lineTo(192, 116)
      ..quadraticBezierTo(202, 116, 203, 106)
      ..lineTo(209, 47)
      ..quadraticBezierTo(210, 35, 196, 35)
      ..lineTo(128, 39)
      ..quadraticBezierTo(121, 39, 121, 48)
      ..lineTo(119, 111)
      ..lineTo(116, 48)
      ..quadraticBezierTo(116, 39, 109, 39)
      ..close();
    canvas.drawPath(pages, Paint()..color = const Color(0xFFFFFCF0));
    final line = Paint()
      ..color = const Color(0xFFF0DACD)
      ..strokeWidth = 2.4;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(48, 60 + i * 15), Offset(106, 63 + i * 15), line);
      canvas.drawLine(Offset(136, 63 + i * 15), Offset(193, 60 + i * 15), line);
    }
    canvas.drawPath(
      Path()
        ..moveTo(169, 32)
        ..lineTo(182, 33)
        ..lineTo(178, 78)
        ..lineTo(172, 69)
        ..lineTo(163, 79)
        ..close(),
      Paint()..color = const Color(0xFFC01D54),
    );
    // Two page turns per repeating cycle, with a brief rest between turns.
    if (animation.value > 0 && animation.value < 1) {
      final phase = ((animation.value * 2 % 1) / 0.82).clamp(0.0, 1.0);
      if (phase > 0 && phase < 1) {
        final turn = Curves.easeInOutCubic.transform(phase);
        final angle = math.pi * turn;
        final edge = 120 + 83 * math.cos(angle);
        final lift = math.sin(angle);
        final page = Path()
          ..moveTo(120, 40)
          ..quadraticBezierTo(
            (120 + edge) / 2,
            38 - 26 * lift,
            edge,
            36 - 16 * lift,
          )
          ..lineTo(edge - 5 * math.cos(angle), 116 - 8 * lift)
          ..quadraticBezierTo((120 + edge) / 2, 119 - 18 * lift, 120, 122)
          ..close();
        canvas.drawShadow(page, const Color(0x55000000), 3 * lift, false);
        canvas.drawPath(
          page,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFFCF0),
              const Color(0xFFEAD9C0),
              lift * 0.55,
            )!,
        );
        final pageLine = Paint()
          ..color = const Color(0xFFECD5C6)
          ..strokeWidth = 2;
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(120 + 15 * math.cos(angle), 63 + i * 15 - 5 * lift),
            Offset(120 + 68 * math.cos(angle), 60 + i * 15 - 13 * lift),
            pageLine,
          );
        }
      }
    }
    final star = Paint()..color = const Color(0xFFFFEFB1);
    canvas.drawCircle(const Offset(10, 58), 3, star);
    canvas.drawCircle(const Offset(233, 106), 2.5, star);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
