import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingDisposable implements Disposable {
  @override
  void dispose() => throw Exception('disposal failed');
}

class _CountingDisposable implements Disposable {
  int disposeCount = 0;
  @override
  void dispose() => disposeCount++;
}

void main() {
  group('Edge Case Tests', () {
    test('one resource throws — others still dispose', () {
      final registry = DisposeRegistry(debugLabel: 'fail-safe');
      final good1 = _CountingDisposable();
      final bad = _ThrowingDisposable();
      final good2 = _CountingDisposable();

      registry.register(good1);
      registry.register(bad);
      registry.register(good2);

      // Should not throw — errors are caught internally
      expect(() => registry.disposeAll(), returnsNormally);
      expect(good1.disposeCount, equals(1));
      expect(good2.disposeCount, equals(1));
    });

    test('registration after disposeAll is rejected (assert in debug)', () {
      final registry = DisposeRegistry(debugLabel: 'post-dispose');
      registry.disposeAll();

      // In debug mode, this should assert
      expect(
        () => registry.register(Object(), disposeCallback: () {}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('TrackedResource toString provides useful debug info', () {
      final tracked = DisposeEngine.createTracked(
        TextEditingController(),
      )!;

      final str = tracked.toString();
      expect(str, contains('TrackedResource'));
      expect(str, contains('TextEditingController'));
      expect(str, contains('disposed: false'));

      tracked.dispose();
      final str2 = tracked.toString();
      expect(str2, contains('disposed: true'));
    });

    test('ScrollController auto-detection and disposal', () {
      final registry = DisposeRegistry(debugLabel: 'scroll');
      final controller = ScrollController();
      registry.register(controller);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();

      // ScrollController extends ChangeNotifier — addListener should throw
      expect(() => controller.addListener(() {}), throwsFlutterError);
    });

    test('FocusNode auto-detection and disposal', () {
      final registry = DisposeRegistry(debugLabel: 'focus');
      final node = FocusNode();
      registry.register(node);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();

      // FocusNode extends ChangeNotifier
      expect(() => node.addListener(() {}), throwsFlutterError);
    });

    test('ValueNotifier auto-detection and disposal', () {
      final registry = DisposeRegistry(debugLabel: 'value');
      final notifier = ValueNotifier<int>(0);
      registry.register(notifier);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();

      expect(() => notifier.addListener(() {}), throwsFlutterError);
    });

    test('StreamController auto-detection and disposal', () {
      final registry = DisposeRegistry(debugLabel: 'stream');
      final controller = StreamController<int>();
      registry.register(controller);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();
      expect(controller.isClosed, isTrue);
    });

    test('Timer auto-detection and cancellation', () {
      final registry = DisposeRegistry(debugLabel: 'timer');
      final timer = Timer(const Duration(days: 1), () {});
      registry.register(timer);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();
      expect(timer.isActive, isFalse);
    });

    test('StreamSubscription auto-detection and cancellation', () async {
      final registry = DisposeRegistry(debugLabel: 'sub');
      final controller = StreamController<int>();
      final sub = controller.stream.listen((_) {});
      registry.register(sub);

      expect(registry.resourceCount, equals(1));
      registry.disposeAll();

      // Clean up the stream controller separately
      await controller.close();
    });

    test('multiple different types in one registry', () async {
      final registry = DisposeRegistry(debugLabel: 'multi');
      final text = TextEditingController();
      final scroll = ScrollController();
      final focus = FocusNode();
      final value = ValueNotifier<String>('hello');
      final stream = StreamController<int>();
      final timer = Timer(const Duration(days: 1), () {});
      final custom = _CountingDisposable();

      registry.register(text);
      registry.register(scroll);
      registry.register(focus);
      registry.register(value);
      registry.register(stream);
      registry.register(timer);
      registry.register(custom);

      expect(registry.resourceCount, equals(7));
      registry.disposeAll();

      expect(stream.isClosed, isTrue);
      expect(timer.isActive, isFalse);
      expect(custom.disposeCount, equals(1));
    });

    test('disposeResource on non-registered object is no-op', () {
      final registry = DisposeRegistry(debugLabel: 'noop');
      expect(() => registry.disposeResource(Object()), returnsNormally);
    });

    test('isRegistered returns correct state', () {
      final registry = DisposeRegistry(debugLabel: 'query');
      final obj = _CountingDisposable();

      expect(registry.isRegistered(obj), isFalse);
      registry.register(obj);
      expect(registry.isRegistered(obj), isTrue);
      registry.unregister(obj);
      expect(registry.isRegistered(obj), isFalse);
    });

    testWidgets('nested AutoDisposeScopes — child disposes before parent',
        (tester) async {
      final order = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            debugLabel: 'parent',
            child: Builder(
              builder: (parentCtx) {
                AutoDispose.of(parentCtx).register(
                  Object(),
                  disposeCallback: () => order.add('parent'),
                );
                return AutoDisposeScope(
                  debugLabel: 'child',
                  child: Builder(
                    builder: (childCtx) {
                      AutoDispose.of(childCtx).register(
                        Object(),
                        disposeCallback: () => order.add('child'),
                      );
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Child scope should dispose before parent scope
      expect(order, equals(['child', 'parent']));
    });

    test('addDisposeListener fires after all resources disposed', () {
      final registry = DisposeRegistry(debugLabel: 'listener');
      final obj = _CountingDisposable();
      var listenerFired = false;
      var objWasDisposedWhenListenerFired = false;

      registry.register(obj);
      registry.addDisposeListener(() {
        listenerFired = true;
        objWasDisposedWhenListenerFired = obj.disposeCount > 0;
      });

      registry.disposeAll();
      expect(listenerFired, isTrue);
      expect(objWasDisposedWhenListenerFired, isTrue);
    });

    test('DisposeState skips already-disposed resources', () {
      final registry = DisposeRegistry(debugLabel: 'state');
      var disposeCalled = false;

      final obj = _MockDisposeStateObj();
      obj.markDisposed(); // Pre-dispose

      registry.register(obj, disposeCallback: () => disposeCalled = true);
      registry.disposeAll();

      // Should be skipped because isDisposed returns true
      expect(disposeCalled, isFalse);
    });
  });
}

class _MockDisposeStateObj implements DisposeState {
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  void markDisposed() => _disposed = true;
}
