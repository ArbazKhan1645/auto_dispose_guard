import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimationController Tests', () {
    testWidgets('disposes AnimationController registered via mixin',
        (tester) async {
      late AnimationController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: _AnimWidget(
            onInit: (c) => controller = c,
          ),
        ),
      );

      expect(controller, isNotNull);

      // Remove widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // After dispose, using the controller should throw
      expect(() => controller.forward(), throwsAssertionError);
    });

    testWidgets('disposes AnimationController while animation is running',
        (tester) async {
      late AnimationController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: _AnimWidget(
            onInit: (c) {
              controller = c;
              c.repeat(); // Start continuous animation
            },
          ),
        ),
      );

      // Let a few frames pass
      await tester.pump(const Duration(milliseconds: 100));

      // Remove widget — should dispose cleanly despite active animation
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(() => controller.forward(), throwsAssertionError);
    });

    testWidgets('disposes multiple AnimationControllers', (tester) async {
      late AnimationController c1;
      late AnimationController c2;
      late AnimationController c3;

      await tester.pumpWidget(
        MaterialApp(
          home: _MultiAnimWidget(
            onInit: (controllers) {
              c1 = controllers[0];
              c2 = controllers[1];
              c3 = controllers[2];
            },
          ),
        ),
      );

      // Start animations
      c1.forward();
      c2.repeat();
      await tester.pump(const Duration(milliseconds: 50));

      // Dispose all
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(() => c1.forward(), throwsAssertionError);
      expect(() => c2.forward(), throwsAssertionError);
      expect(() => c3.forward(), throwsAssertionError);
    });

    testWidgets('rapid animation create/dispose cycles', (tester) async {
      for (var i = 0; i < 20; i++) {
        late AnimationController controller;

        await tester.pumpWidget(
          MaterialApp(
            home: _AnimWidget(
              onInit: (c) {
                controller = c;
                c.forward();
              },
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(() => controller.forward(), throwsAssertionError,
            reason: 'Cycle $i: controller not disposed');
      }
    });
  });
}

// ─── Test Widgets ──────────────────────────────────────────────────────────────

class _AnimWidget extends StatefulWidget {
  const _AnimWidget({required this.onInit});
  final void Function(AnimationController) onInit;

  @override
  State<_AnimWidget> createState() => _AnimWidgetState();
}

class _AnimWidgetState extends State<_AnimWidget>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    final controller = register(
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    widget.onInit(controller);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _MultiAnimWidget extends StatefulWidget {
  const _MultiAnimWidget({required this.onInit});
  final void Function(List<AnimationController>) onInit;

  @override
  State<_MultiAnimWidget> createState() => _MultiAnimWidgetState();
}

class _MultiAnimWidgetState extends State<_MultiAnimWidget>
    with TickerProviderStateMixin, AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    final controllers = List.generate(
      3,
      (_) => register(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
    widget.onInit(controllers);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
