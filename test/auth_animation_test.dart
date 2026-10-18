import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_library_client/core/theme/app_theme.dart';
import 'package:open_library_client/features/auth/auth_widgets.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  ),
);

Future<Uint8List> bookPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(BookIllustration),
      matching: find.byType(RepaintBoundary),
    ),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

Future<Uint8List> sweepPixels(WidgetTester tester) async {
  final painter = tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(AuthButton),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.foregroundPainter != null,
          ),
        ),
      )
      .foregroundPainter!;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(300, 56));
  final picture = recorder.endRecording();
  return (await tester.runAsync(() async {
    final image = await picture.toImage(300, 56);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void main() {
  const book = SizedBox(height: 138, child: BookIllustration());

  testWidgets('book continues turning after multiple complete cycles', (
    tester,
  ) async {
    await tester.pumpWidget(host(book));
    final initial = await bookPixels(tester);
    await tester.pump(const Duration(milliseconds: 550));
    final turning = await bookPixels(tester);
    expect(turning, isNot(orderedEquals(initial)));
    await tester.pump(const Duration(seconds: 10));
    expect(await bookPixels(tester), orderedEquals(turning));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await bookPixels(tester), isNot(orderedEquals(turning)));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stops an active page turn and stays still', (
    tester,
  ) async {
    await tester.pumpWidget(host(book));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(host(book, reduceMotion: true));
    await tester.pumpAndSettle();
    final still = await bookPixels(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(await bookPixels(tester), orderedEquals(still));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(host(book));
    await tester.pump(const Duration(milliseconds: 550));
    expect(await bookPixels(tester), isNot(orderedEquals(still)));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('button compresses on press, restores on release or cancel', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AuthButton(label: 'Tiếp tục', loading: false, onPressed: () => calls++),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FilledButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    expect(calls, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(calls, 1);

    final cancelled = await tester.startGesture(
      tester.getCenter(find.byType(FilledButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(calls, 1);
  });

  testWidgets('keyboard focus is visible and activation calls back once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        AuthButton(label: 'Tiếp tục', loading: false, onPressed: () => calls++),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final decoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration!
            as BoxDecoration;
    expect(decoration.border, Border.all(color: Colors.white, width: 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets(
    'reduced motion keeps button still and loading blocks activation',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          AuthButton(
            label: 'Tiếp tục',
            loading: false,
            onPressed: () => calls++,
          ),
          reduceMotion: true,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
      expect(scale.duration, Duration.zero);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pumpWidget(
        host(
          AuthButton(
            label: 'Tiếp tục',
            loading: true,
            onPressed: () => calls++,
          ),
          reduceMotion: true,
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
  testWidgets('book stops scheduling frames when its route is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TickerMode(enabled: false, child: book)),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(host(const TickerMode(enabled: true, child: book)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login sweep moves during loading, blocks duplicate activation, and replays',
    (tester) async {
      final loading = ValueNotifier(false);
      addTearDown(loading.dispose);
      var calls = 0;
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (context, busy, _) => AuthButton(
              label: 'Đăng nhập',
              loading: busy,
              sweepOnPress: true,
              onPressed: () {
                calls++;
                loading.value = true;
              },
            ),
          ),
        ),
      );
      final idle = await sweepPixels(tester);
      await tester.tap(find.byType(FilledButton));
      expect(calls, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      final middle = await sweepPixels(tester);
      expect(middle, isNot(orderedEquals(idle)));
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 90));
      expect(await sweepPixels(tester), isNot(orderedEquals(middle)));
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 150));
      expect(await sweepPixels(tester), orderedEquals(idle));
      loading.value = false;
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      expect(await sweepPixels(tester), orderedEquals(middle));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion suppresses the login sweep without blocking activation',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          AuthButton(
            label: 'Đăng nhập',
            loading: false,
            sweepOnPress: true,
            onPressed: () => calls++,
          ),
          reduceMotion: true,
        ),
      );
      final idle = await sweepPixels(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      expect(await sweepPixels(tester), orderedEquals(idle));
      expect(calls, 1);
      await tester.pumpAndSettle();
    },
  );
}
