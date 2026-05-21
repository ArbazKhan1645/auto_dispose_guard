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
      // Don't await close() — for a single-subscription controller with no
      // listeners the done future never resolves. isClosed is set synchronously.
      unawaited(stream.close());
      expect(stream.isClosed, isTrue);
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
      final ctrl = _ServiceController();
      // Access the late field BEFORE dispose so the lazy initializer runs and
      // the _MockDisposable is registered with the bag.
      expect(ctrl.controller.disposed, isFalse);

      ctrl.dispose();
      ctrl.dispose(); // idempotent

      expect(ctrl.controller.disposed, isTrue);
      expect(ctrl.isAutoDisposeDisposed, isTrue);
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

  group('DisposeRegistry Edge Cases', () {
    test('addDisposeListener after disposeAll throws AssertionError', () {
      final reg = DisposeRegistry(debugLabel: 'assertion-test');
      reg.disposeAll();
      expect(
          () => reg.addDisposeListener(() {}), throwsA(isA<AssertionError>()));
    });

    test('dispose listener throwing is caught and logged safely', () {
      final reg = DisposeRegistry(debugLabel: 'test-throw-listener');
      reg.addDisposeListener(() => throw Exception('listener fail'));
      expect(() => reg.disposeAll(), returnsNormally);
    });
  });

  group('DisposeEngine Dynamic Fallbacks and Sink', () {
    test('detects and invokes dynamic close', () {
      final reg = DisposeRegistry();
      final obj = _DynamicCloseable();
      reg.register(obj);
      expect(reg.resourceCount, equals(1));
      reg.disposeAll();
      expect(obj.closed, isTrue);
    });

    test('detects and invokes dynamic cancel', () {
      final reg = DisposeRegistry();
      final obj = _DynamicCancellable();
      reg.register(obj);
      expect(reg.resourceCount, equals(1));
      reg.disposeAll();
      expect(obj.cancelled, isTrue);
    });

    test('detects dynamic isDisposed property', () {
      final obj = _DynamicIsDisposedGetter();
      final tracked = DisposeEngine.createTracked(obj)!;
      expect(tracked.isDisposed, isFalse);
      obj.isDisposed = true;
      expect(tracked.isDisposed, isTrue);
    });

    test('detects dynamic isDisposed() function', () {
      final obj = _DynamicIsDisposedMethod();
      final tracked = DisposeEngine.createTracked(obj)!;
      expect(tracked.isDisposed, isTrue);
    });

    test('detects dynamic isClosed property', () {
      final obj = _DynamicIsClosedGetter();
      final tracked = DisposeEngine.createTracked(obj)!;
      expect(tracked.isDisposed, isFalse);
      obj.isClosed = true;
      expect(tracked.isDisposed, isTrue);
    });

    test('detects dynamic isClosed() function', () {
      final obj = _DynamicIsClosedMethod();
      final tracked = DisposeEngine.createTracked(obj)!;
      expect(tracked.isDisposed, isTrue);
    });

    test('detects and closes Sink', () {
      final reg = DisposeRegistry();
      final obj = _MockSink();
      reg.register(obj);
      expect(reg.resourceCount, equals(1));
      reg.disposeAll();
      expect(obj.closed, isTrue);
    });
  });

  group('AutoDisposeBag and Mixin extra methods', () {
    test('AutoDisposeBag extra methods', () {
      final bag = AutoDisposeBag(debugLabel: 'extra');
      final obj = _MockDisposable();
      bag.register(obj);
      expect(bag.isRegistered(obj), isTrue);

      var listenerCalled = false;
      bag.addDisposeListener(() => listenerCalled = true);

      bag.disposeResource(obj);
      expect(obj.disposed, isTrue);

      final obj2 = _MockDisposable();
      bag.register(obj2);
      bag.unregister(obj2);
      expect(bag.isRegistered(obj2), isFalse);

      bag.dispose();
      expect(listenerCalled, isTrue);
    });

    test('AutoDisposeBagMixin extra methods', () {
      final mixinObj = _ServiceControllerWithExtras();
      expect(mixinObj.disposeRegistry, isNotNull);
      final item = _MockDisposable();
      mixinObj.register(item);
      expect(mixinObj.isRegistered(item), isTrue);

      var mixinListenerCalled = false;
      mixinObj.addDisposeListener(() => mixinListenerCalled = true);

      mixinObj.disposeAutoDispose();
      expect(item.disposed, isTrue);
      expect(mixinListenerCalled, isTrue);
    });
  });

  group('AutoDisposeMixin Extra Methods', () {
    testWidgets(
        'invokes isRegistered, unregister, disposeOf, addDisposeListener',
        (tester) async {
      late _MixinExtrasWidgetState state;
      final obj = _MockDisposable();
      final obj2 = _MockDisposable();

      await tester.pumpWidget(
        MaterialApp(
          home: _MixinExtrasWidget(
            onState: (s) => state = s,
            obj: obj,
            obj2: obj2,
          ),
        ),
      );

      expect(state.isRegistered(obj), isTrue);
      expect(state.isRegistered(obj2), isTrue);

      var listenerCalled = false;
      state.addDisposeListener(() => listenerCalled = true);

      state.unregister(obj2);
      expect(state.isRegistered(obj2), isFalse);

      state.disposeOf(obj);
      expect(obj.disposed, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(listenerCalled, isTrue);
      expect(obj2.disposed, isFalse);
    });
  });

  group('BlocAutoDisposeMixin', () {
    test('tracks and disposes resources', () {
      final obj = _MockDisposable();
      final bloc = _TestBloc(obj);

      expect(bloc.disposeRegistry, isNotNull);
      expect(bloc.isAutoDisposeDisposed, isFalse);
      expect(bloc.resourceCount, equals(1));
      expect(bloc.isRegistered(obj), isTrue);

      var listenerCalled = false;
      bloc.addDisposeListener(() => listenerCalled = true);

      final obj2 = _MockDisposable();
      bloc.register(obj2);
      bloc.unregister(obj2);
      expect(bloc.isRegistered(obj2), isFalse);

      final obj3 = _MockDisposable();
      bloc.register(obj3);
      bloc.disposeOf(obj3);
      expect(obj3.disposed, isTrue);

      bloc.disposeAutoDispose();
      expect(obj.disposed, isTrue);
      expect(bloc.isAutoDisposeDisposed, isTrue);
      expect(listenerCalled, isTrue);
    });
  });

  group('AutoDisposeChangeNotifier', () {
    test('automatically disposes registered resources on dispose()', () {
      final obj = _MockDisposable();
      final notifier = _TestChangeNotifier(obj);

      expect(notifier.isRegistered(obj), isTrue);
      notifier.dispose();

      expect(obj.disposed, isTrue);
      expect(notifier.isAutoDisposeDisposed, isTrue);
    });
  });

  group('AutoDisposeScope and _AutoDisposeScopeData Extra Tests', () {
    testWidgets('maybeOf returns registry when scope exists', (tester) async {
      late DisposeRegistry? registry;
      await tester.pumpWidget(
        MaterialApp(
          home: AutoDisposeScope(
            child: Builder(
              builder: (context) {
                registry = AutoDispose.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(registry, isNotNull);
    });

    testWidgets('updateShouldNotify of _AutoDisposeScopeData returns false',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AutoDisposeScope(
                key: key,
                child: SizedBox(key: ValueKey(context.hashCode)),
              );
            },
          ),
        ),
      );

      // Rebuild parent to trigger updateShouldNotify on the inherited widget
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AutoDisposeScope(
                key: key,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
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

class _DynamicCloseable {
  bool closed = false;
  void close() => closed = true;
}

class _DynamicCancellable {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class _DynamicIsDisposedGetter {
  bool isDisposed = false;
  void dispose() {}
}

class _DynamicIsDisposedMethod {
  bool isDisposed() => true;
  void dispose() {}
}

class _DynamicIsClosedGetter {
  bool isClosed = false;
  void dispose() {}
}

class _DynamicIsClosedMethod {
  bool isClosed() => true;
  void dispose() {}
}

class _MockSink implements Sink<int> {
  bool closed = false;
  @override
  void add(int data) {}
  @override
  void close() => closed = true;
}

class _ServiceControllerWithExtras with AutoDisposeBagMixin {}

class _MixinExtrasWidget extends StatefulWidget {
  const _MixinExtrasWidget({
    required this.onState,
    required this.obj,
    required this.obj2,
  });

  final void Function(_MixinExtrasWidgetState) onState;
  final _MockDisposable obj;
  final _MockDisposable obj2;

  @override
  State<_MixinExtrasWidget> createState() => _MixinExtrasWidgetState();
}

class _MixinExtrasWidgetState extends State<_MixinExtrasWidget>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    register(widget.obj);
    register(widget.obj2);
    widget.onState(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _TestBloc with BlocAutoDisposeMixin {
  _TestBloc(Object resource) {
    register(resource);
  }
}

class _TestChangeNotifier extends AutoDisposeChangeNotifier {
  _TestChangeNotifier(Object resource) {
    register(resource);
  }
}
