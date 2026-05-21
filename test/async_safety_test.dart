import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Async Safety Tests', () {
    testWidgets('safeExecute does NOT run callback after dispose',
        (tester) async {
      var callbackRan = false;
      late _SafeExecWidgetState stateRef;

      await tester.pumpWidget(
        MaterialApp(
          home: _SafeExecWidget(
            onInit: (state) => stateRef = state,
          ),
        ),
      );

      // Dispose the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Now try safeExecute — should be a no-op since widget is unmounted
      stateRef.safeExecute(() => callbackRan = true);
      expect(callbackRan, isFalse);
    });

    testWidgets('safeExecute runs callback while mounted', (tester) async {
      var callbackRan = false;
      late _SafeExecWidgetState stateRef;

      await tester.pumpWidget(
        MaterialApp(
          home: _SafeExecWidget(
            onInit: (state) => stateRef = state,
          ),
        ),
      );

      stateRef.safeExecute(() => callbackRan = true);
      expect(callbackRan, isTrue);
    });

    testWidgets('safeExecuteAsync does NOT run callback after dispose',
        (tester) async {
      var callbackRan = false;
      late _SafeExecWidgetState stateRef;

      await tester.pumpWidget(
        MaterialApp(
          home: _SafeExecWidget(
            onInit: (state) => stateRef = state,
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      await stateRef.safeExecuteAsync(() async => callbackRan = true);
      expect(callbackRan, isFalse);
    });

    testWidgets('safeExecuteAsync runs callback while mounted',
        (tester) async {
      var callbackRan = false;
      late _SafeExecWidgetState stateRef;

      await tester.pumpWidget(
        MaterialApp(
          home: _SafeExecWidget(
            onInit: (state) => stateRef = state,
          ),
        ),
      );

      await stateRef.safeExecuteAsync(() async => callbackRan = true);
      expect(callbackRan, isTrue);
    });

    testWidgets('TextEditingController used after dispose is caught',
        (tester) async {
      late TextEditingController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: _ControllerWidget(
            onInit: (c) => controller = c,
          ),
        ),
      );

      // Dispose widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Using disposed controller should throw
      expect(() => controller.text = 'test', throwsFlutterError);
    });
  });
}

// ─── Test Widgets ──────────────────────────────────────────────────────────────

class _SafeExecWidget extends StatefulWidget {
  const _SafeExecWidget({required this.onInit});
  final void Function(_SafeExecWidgetState) onInit;

  @override
  State<_SafeExecWidget> createState() => _SafeExecWidgetState();
}

class _SafeExecWidgetState extends State<_SafeExecWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    widget.onInit(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _ControllerWidget extends StatefulWidget {
  const _ControllerWidget({required this.onInit});
  final void Function(TextEditingController) onInit;

  @override
  State<_ControllerWidget> createState() => _ControllerWidgetState();
}

class _ControllerWidgetState extends State<_ControllerWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    final controller = register(TextEditingController());
    widget.onInit(controller);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
