import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _MockDisposeState implements Disposable, DisposeState {
  bool disposeCalled = false;
  bool alreadyDisposed = false;

  @override
  bool get isDisposed => alreadyDisposed;

  @override
  void dispose() => disposeCalled = true;
}

void main() {
  group('DisposeRegistry', () {
    test('registers and disposes supported marker types', () {
      final disposable = _MockDisposable();
      final closeable = _MockCloseable();
      final cancellable = _MockCancellable();
      final reg = DisposeRegistry(debugLabel: 'test')
        ..register(disposable)
        ..register(closeable)
        ..register(cancellable);

      expect(reg.resourceCount, equals(3));
      reg.disposeAll();

      expect(disposable.disposed, isTrue);
      expect(closeable.closed, isTrue);
      expect(cancellable.cancelled, isTrue);
    });

    test('registration and disposeAll are idempotent', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final obj = _MockDisposable();
      reg.register(obj);
      reg.register(obj);
      expect(reg.resourceCount, equals(1));

      reg.disposeAll();
      reg.disposeAll();
      expect(obj.disposed, isTrue);
    });

    test('disposes in LIFO order', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      final order = <int>[];
      reg.register(Object(), disposeCallback: () => order.add(1));
      reg.register(Object(), disposeCallback: () => order.add(2));
      reg.register(Object(), disposeCallback: () => order.add(3));

      reg.disposeAll();
      expect(order, equals([3, 2, 1]));
    });

    test('continues disposing after one resource throws', () {
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

    test('disposeResource disposes and removes one resource', () {
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
      var customCalled = false;
      final obj = _MockDisposable();

      reg.register(obj, disposeCallback: () => customCalled = true);
      reg.disposeAll();

      expect(customCalled, isTrue);
      expect(obj.disposed, isFalse);
    });

    test('skips unknown types', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      reg.register(Object());
      expect(reg.resourceCount, equals(0));
    });

    test('skips disposal when isDisposed returns true', () {
      final reg = DisposeRegistry(debugLabel: 'test');
      var calls = 0;
      reg.register(
        Object(),
        disposeCallback: () => calls++,
        isDisposed: () => true,
      );

      reg.disposeAll();
      expect(calls, equals(0));
    });
  });

  group('DisposeEngine', () {
    test('auto-detects Flutter and dart async types', () async {
      final text = TextEditingController();
      final stream = StreamController<int>();
      final subscription = stream.stream.listen((_) {});
      final timer = Timer(const Duration(days: 1), () {});
      final reg = DisposeRegistry(debugLabel: 'test')
        ..register(text)
        ..register(stream)
        ..register(subscription)
        ..register(timer);

      expect(() => reg.disposeAll(), returnsNormally);
      expect(stream.isClosed, isTrue);
      expect(timer.isActive, isFalse);
    });

    test('skips already closed StreamController', () async {
      final reg = DisposeRegistry(debugLabel: 'test');
      final stream = StreamController<int>();
      reg.register(stream);
      await stream.close();
      expect(() => reg.disposeAll(), returnsNormally);
    });

    test('DisposeState is used as automatic disposed probe', () {
      final obj = _MockDisposeState()..alreadyDisposed = true;
      final tracked = DisposeEngine.createTracked(obj)!;
      tracked.dispose();

      expect(obj.disposeCalled, isFalse);
      expect(tracked.isDisposed, isTrue);
    });
  });

  group('TrackedResource', () {
    test('disposeFn is called exactly once', () {
      var calls = 0;
      final tracked = DisposeEngine.createTracked(
        Object(),
        disposeCallback: () => calls++,
      )!;

      tracked.dispose();
      tracked.dispose();
      expect(calls, equals(1));
    });
  });

  group('AutoDisposeBag', () {
    test('registers and disposes resources outside widgets', () {
      final bag = AutoDisposeBag(debugLabel: 'service');
      final obj = _MockDisposable();

      final returned = bag.register(obj);
      expect(identical(returned, obj), isTrue);
      expect(bag.resourceCount, equals(1));

      bag.dispose();
      bag.dispose();
      expect(obj.disposed, isTrue);
      expect(bag.isDisposed, isTrue);
    });

    test('AutoDisposeBagMixin disposes controller/service resources', () {
      final controller = _ServiceController();
      controller.dispose();
      controller.dispose();

      expect(controller.controller.disposed, isTrue);
      expect(controller.isAutoDisposeDisposed, isTrue);
    });
  });

  group('AutoDisposeScope', () {
    testWidgets('disposes resources when removed from tree', (tester) async {
      final obj = _MockDisposable();
      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            child: Builder(
              builder: (ctx) {
                AutoDispose.of(ctx).register(obj);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(obj.disposed, isFalse);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });

    testWidgets('of throws when no scope exists', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(() => AutoDispose.of(ctx), throwsA(isA<FlutterError>()));
      expect(AutoDispose.maybeOf(ctx), isNull);
    });
  });

  group('AutoDisposeMixin', () {
    testWidgets('disposes resources on State.dispose', (tester) async {
      final obj = _MockDisposable();
      await tester.pumpWidget(MaterialApp(home: _MixinTestWidget(obj)));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });

    testWidgets('register returns the resource', (tester) async {
      late TextEditingController returned;
      await tester.pumpWidget(
        MaterialApp(
          home: _MixinReturnTestWidget(onCapture: (c) => returned = c),
        ),
      );
      expect(returned, isA<TextEditingController>());
    });
  });

  group('autoDispose extension', () {
    testWidgets('registers and returns same instance', (tester) async {
      final obj = _MockDisposable();
      late _MockDisposable returned;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            child: Builder(
              builder: (ctx) {
                returned = obj.autoDispose(ctx);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(identical(returned, obj), isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(obj.disposed, isTrue);
    });
  });
}

class _ServiceController with AutoDisposeBagMixin {
  late final controller = register(_MockDisposable());

  void dispose() => disposeAutoDispose();
}

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
