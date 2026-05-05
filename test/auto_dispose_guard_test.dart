import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Test doubles ─────────────────────────────────────────────────────────────

class _MockDisposable implements Disposable {
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}

class _MockCloseable implements Closeable {
  bool closed = false;
  @override
  void close() => closed = true;
}

class _MockCancellable implements Cancellable {
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── DisposeRegistry ─────────────────────────────────────────────────────

  group('DisposeRegistry', () {
    test('registers and disposes a Disposable', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockDisposable();

      reg.register(obj);
      expect(reg.isRegistered(obj), isTrue);
      expect(reg.resourceCount, equals(1));

      reg.disposeAll();
      expect(obj.disposed, isTrue);
    });

    test('registers and disposes a Closeable', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockCloseable();
      reg.register(obj);
      reg.disposeAll();
      expect(obj.closed, isTrue);
    });

    test('registers and disposes a Cancellable', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockCancellable();
      reg.register(obj);
      reg.disposeAll();
      expect(obj.cancelled, isTrue);
    });

    test('registration is idempotent', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockDisposable();
      reg.register(obj);
      reg.register(obj);
      expect(reg.resourceCount, equals(1));
    });

    test('disposeAll is idempotent', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockDisposable();
      reg.register(obj);
      reg.disposeAll();
      reg.disposeAll();
      expect(obj.disposed, isTrue);
    });

    test('disposes in LIFO order', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final order = <int>[];
      final a = Object(), b = Object(), c = Object();
      reg.register(a, disposeCallback: () => order.add(1));
      reg.register(b, disposeCallback: () => order.add(2));
      reg.register(c, disposeCallback: () => order.add(3));
      reg.disposeAll();
      expect(order, equals([3, 2, 1]));
    });

    test('fail-safe: continues disposing after one error', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final good = _MockDisposable();
      reg.register(Object(), disposeCallback: () => throw Exception('boom'));
      reg.register(good);
      expect(() => reg.disposeAll(), returnsNormally);
      expect(good.disposed, isTrue);
    });

    test('unregister removes without disposing', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockDisposable();
      reg.register(obj);
      reg.unregister(obj);
      reg.disposeAll();
      expect(obj.disposed, isFalse);
    });

    test('disposeResource disposes and removes single resource', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final a = _MockDisposable();
      final b = _MockDisposable();
      reg.register(a);
      reg.register(b);
      reg.disposeResource(a);
      expect(a.disposed, isTrue);
      expect(reg.isRegistered(a), isFalse);
      expect(reg.resourceCount, equals(1));
    });

    test('disposeCallback overrides auto-detection', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      bool customCalled = false;
      final obj = _MockDisposable();
      reg.register(obj, disposeCallback: () => customCalled = true);
      reg.disposeAll();
      expect(customCalled, isTrue);
      expect(obj.disposed, isFalse);
    });

    test('skips unknown type — resourceCount stays 0', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      reg.register(Object());
      expect(reg.resourceCount, equals(0));
    });
  });

  // ── DisposeEngine integration ────────────────────────────────────────────

  group('DisposeEngine — Flutter types', () {
    test('auto-detects TextEditingController (ChangeNotifier)', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final ctrl = TextEditingController();
      reg.register(ctrl);
      expect(reg.resourceCount, equals(1));
      expect(() => reg.disposeAll(), returnsNormally);
    });

    test('auto-detects StreamController — closes it', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final stream = StreamController<int>();
      reg.register(stream);
      reg.disposeAll();
      expect(stream.isClosed, isTrue);
    });

    test('auto-detects StreamSubscription — cancels it', () async {
      final sc = StreamController<int>();
      bool received = false;
      final sub = sc.stream.listen((_) => received = true);
      final reg = DisposeRegistry(debugLabel: 'test');
      reg.register(sub);
      reg.disposeAll();
      sc.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(received, isFalse);
      await sc.close();
    });
  });

  // ── TrackedResource ──────────────────────────────────────────────────────

  group('TrackedResource', () {
    test('disposeFn called exactly once', () {
      int calls = 0;
      final tracked = DisposeEngine.createTracked(
        Object(),
        disposeCallback: () => calls++,
      )!;
      tracked.dispose();
      tracked.dispose();
      expect(calls, equals(1));
    });

    test('isDisposed reflects state', () {
      final tracked = DisposeEngine.createTracked(_MockDisposable())!;
      expect(tracked.isDisposed, isFalse);
      tracked.dispose();
      expect(tracked.isDisposed, isTrue);
    });
  });

  // ── AutoDisposeScope widget ──────────────────────────────────────────────

  group('AutoDisposeScope', () {
    testWidgets('disposes resources when removed from tree', (tester) async {
      final obj = _MockDisposable();
      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            child: Builder(builder: (ctx) {
              AutoDispose.of(ctx).register(obj);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(obj.disposed, isFalse);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });

    testWidgets('of() throws when no scope in tree', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      expect(() => AutoDispose.of(ctx), throwsA(isA<FlutterError>()));
    });

    testWidgets('maybeOf() returns null when no scope in tree', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      expect(AutoDispose.maybeOf(ctx), isNull);
    });
  });

  // ── AutoDisposeMixin ─────────────────────────────────────────────────────

  group('AutoDisposeMixin', () {
    testWidgets('disposes resources on State.dispose', (tester) async {
      final obj = _MockDisposable();
      await tester.pumpWidget(MaterialApp(home: _MixinTestWidget(obj)));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });

    testWidgets('register() returns the resource', (tester) async {
      late TextEditingController returned;
      await tester.pumpWidget(MaterialApp(
        home: _MixinReturnTestWidget(onCapture: (c) => returned = c),
      ));
      expect(returned, isA<TextEditingController>());
    });
  });

  // ── autoDispose extension ────────────────────────────────────────────────

  group('autoDispose extension', () {
    testWidgets('registers and returns same instance', (tester) async {
      final obj = _MockDisposable();
      late _MockDisposable returned;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            child: Builder(builder: (ctx) {
              returned = obj.autoDispose(ctx);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(identical(returned, obj), isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });
  });
}

// ─── Widget helpers ───────────────────────────────────────────────────────────

class _MixinTestWidget extends StatefulWidget {
  const _MixinTestWidget(this.obj);
  final _MockDisposable obj;

  @override
  State<_MixinTestWidget> createState() => _MixinTestWidgetState();
}

class _MixinTestWidgetState extends State<_MixinTestWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    register(widget.obj);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _MixinReturnTestWidget extends StatefulWidget {
  const _MixinReturnTestWidget({required this.onCapture});
  final void Function(TextEditingController) onCapture;

  @override
  State<_MixinReturnTestWidget> createState() => _MixinReturnTestWidgetState();
}

class _MixinReturnTestWidgetState extends State<_MixinReturnTestWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    widget.onCapture(register(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
