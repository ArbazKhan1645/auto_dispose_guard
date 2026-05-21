import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StressDisposable implements Disposable {
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}

void main() {
  group('Stress Tests', () {
    test('handles 10,000 registrations and disposals', () {
      final registry = DisposeRegistry(debugLabel: 'stress');
      final objects = List.generate(10000, (_) => _StressDisposable());

      for (final obj in objects) {
        registry.register(obj);
      }
      expect(registry.resourceCount, equals(10000));

      registry.disposeAll();

      for (final obj in objects) {
        expect(obj.disposed, isTrue);
      }
    });

    test('duplicate registration storm — same object 1000 times', () {
      final registry = DisposeRegistry(debugLabel: 'dup-stress');
      final obj = _StressDisposable();

      for (var i = 0; i < 1000; i++) {
        registry.register(obj);
      }
      expect(registry.resourceCount, equals(1));

      registry.disposeAll();
      expect(obj.disposed, isTrue);
    });

    test('LIFO order maintained with 1000 resources', () {
      final registry = DisposeRegistry(debugLabel: 'lifo-stress');
      final order = <int>[];

      for (var i = 0; i < 1000; i++) {
        registry.register(Object(), disposeCallback: () => order.add(i));
      }

      registry.disposeAll();

      // Verify strict LIFO
      for (var i = 0; i < 1000; i++) {
        expect(order[i], equals(999 - i));
      }
    });

    test('1000 TextEditingControllers register and dispose', () {
      final registry = DisposeRegistry(debugLabel: 'controllers');
      final controllers = List.generate(1000, (_) => TextEditingController());

      for (final c in controllers) {
        registry.register(c);
      }
      expect(registry.resourceCount, equals(1000));

      registry.disposeAll();

      // After dispose, addListener should throw
      for (final c in controllers) {
        expect(() => c.addListener(() {}), throwsFlutterError);
      }
    });

    test('mixed type stress — 500 controllers + 500 streams + 500 timers', () {
      final registry = DisposeRegistry(debugLabel: 'mixed');
      final textControllers =
          List.generate(500, (_) => TextEditingController());
      final streams = List.generate(500, (_) => StreamController<int>());
      final timers =
          List.generate(500, (_) => Timer(const Duration(days: 1), () {}));

      for (final c in textControllers) {
        registry.register(c);
      }
      for (final s in streams) {
        registry.register(s);
      }
      for (final t in timers) {
        registry.register(t);
      }

      expect(registry.resourceCount, equals(1500));
      registry.disposeAll();

      for (final s in streams) {
        expect(s.isClosed, isTrue);
      }
      for (final t in timers) {
        expect(t.isActive, isFalse);
      }
    });

    testWidgets('navigation stress — 100 push/pop cycles', (tester) async {
      final disposedFlags = <bool>[];

      for (var i = 0; i < 100; i++) {
        final obj = _StressDisposable();
        disposedFlags.add(false);
        final idx = i;

        await tester.pumpWidget(
          MaterialApp(
            home: AutoDisposeScope(
              debugLabel: 'nav-$i',
              child: Builder(
                builder: (ctx) {
                  AutoDispose.of(ctx).register(
                    obj,
                    disposeCallback: () {
                      obj.disposed = true;
                      disposedFlags[idx] = true;
                    },
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }

      for (var i = 0; i < 100; i++) {
        expect(disposedFlags[i], isTrue, reason: 'Cycle $i not disposed');
      }
    });

    testWidgets('mixin stress — 100 widget mount/unmount cycles',
        (tester) async {
      for (var i = 0; i < 100; i++) {
        final obj = _StressDisposable();

        await tester.pumpWidget(
          MaterialApp(home: _StressMixinWidget(obj)),
        );
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(obj.disposed, isTrue, reason: 'Cycle $i not disposed');
      }
    });

    test('concurrent remove during iteration', () {
      final registry = DisposeRegistry(debugLabel: 'concurrent');
      final objects = List.generate(100, (_) => _StressDisposable());

      for (final obj in objects) {
        registry.register(obj);
      }

      // Remove half before disposing all
      for (var i = 0; i < 50; i++) {
        registry.unregister(objects[i]);
      }

      registry.disposeAll();

      // First 50 were unregistered — should NOT be disposed
      for (var i = 0; i < 50; i++) {
        expect(objects[i].disposed, isFalse,
            reason: 'Object $i should not be disposed');
      }
      // Last 50 should be disposed
      for (var i = 50; i < 100; i++) {
        expect(objects[i].disposed, isTrue,
            reason: 'Object $i should be disposed');
      }
    });
  });
}

class _StressMixinWidget extends StatefulWidget {
  const _StressMixinWidget(this.obj);
  final _StressDisposable obj;

  @override
  State<_StressMixinWidget> createState() => _StressMixinWidgetState();
}

class _StressMixinWidgetState extends State<_StressMixinWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    register(widget.obj);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
