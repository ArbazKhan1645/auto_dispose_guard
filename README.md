# auto_dispose_guard

Safe automatic disposal for Flutter controllers, streams, timers, services, and custom resources.

AutoDisposeGuard removes the repetitive `dispose()`, `close()`, and `cancel()` boilerplate from Flutter apps while keeping cleanup idempotent and fail-safe.

## What's New In 1.0.2

- `AutoDisposeBag` for plain Dart classes, repositories, blocs, GetX services, and Provider objects.
- `AutoDisposeBagMixin` for controller/service classes where you want `register()` without a widget `State`.
- `isDisposed` guards to skip resources that were already disposed manually.
- `DisposeState` marker interface for custom resources that can report disposal state.
- Built-in skip guards for already closed `StreamController`s and inactive `Timer`s.
- Shorter pubspec description so pub.dev can award the missing pubspec points.

## Installation

```yaml
dependencies:
  auto_dispose_guard: ^1.0.2
```

```dart
import 'package:auto_dispose_guard/auto_dispose_guard.dart';
```

## Widget State Usage

Use `AutoDisposeMixin` in a `State` class and register resources inline.

```dart
class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  late final name = register(TextEditingController());
  late final focus = register(FocusNode());
  late final animation = register(
    AnimationController(vsync: this, duration: kThemeAnimationDuration),
  );
  late final stream = register(StreamController<String>.broadcast());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

No manual `dispose()` override is needed for registered resources.

## GetX Controllers And Services

AutoDisposeGuard does not depend on GetX, but works cleanly with it through `AutoDisposeBagMixin`.

```dart
class LoginController extends GetxController with AutoDisposeBagMixin {
  late final email = register(TextEditingController());
  late final password = register(TextEditingController());
  late final timer = register(Timer.periodic(const Duration(seconds: 1), (_) {}));

  @override
  void onClose() {
    disposeAutoDispose();
    super.onClose();
  }
}
```

```dart
class SocketService extends GetxService with AutoDisposeBagMixin {
  late final messages = register(StreamController<String>.broadcast());

  @override
  void onClose() {
    disposeAutoDispose();
    super.onClose();
  }
}
```

## Provider / ChangeNotifier Usage

```dart
class SearchProvider extends ChangeNotifier with AutoDisposeBagMixin {
  late final query = register(TextEditingController());
  late final scroll = register(ScrollController());

  @override
  void dispose() {
    disposeAutoDispose();
    super.dispose();
  }
}
```

## Plain Dart Classes

Use `AutoDisposeBag` when a mixin is not a good fit.

```dart
class Repository {
  Repository() : _bag = AutoDisposeBag(debugLabel: 'Repository');

  final AutoDisposeBag _bag;

  late final events = _bag.register(StreamController<int>.broadcast());

  void dispose() => _bag.dispose();
}
```

## Scope Usage

Wrap a route or subtree in `AutoDisposeScope` and register from descendants.

```dart
MaterialPageRoute<void>(
  builder: (_) => const AutoDisposeScope(
    debugLabel: 'ProfileRoute',
    child: ProfileScreen(),
  ),
);
```

```dart
final controller = TextEditingController().autoDispose(context);
AutoDispose.of(context).register(StreamController<int>());
```

## Already Disposed Guards

If a resource may be disposed manually before the owner closes, pass an `isDisposed` probe.

```dart
late final socket = register(
  MySocket(),
  onDispose: () => socket.close(),
  isDisposed: () => socket.isClosed,
);
```

Or implement `DisposeState` on your own type.

```dart
class MyCache implements Disposable, DisposeState {
  bool _closed = false;

  @override
  bool get isDisposed => _closed;

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
  }
}
```

## Auto Detection

AutoDisposeGuard uses type checks, not reflection.

| Type | Method |
| --- | --- |
| `Disposable` | `dispose()` |
| `Closeable` | `close()` |
| `Cancellable` | `cancel()` |
| `ChangeNotifier` | `dispose()` |
| `StreamController` | `close()` |
| `StreamSubscription` | `cancel()` |
| `Timer` | `cancel()` |
| Custom callback | `onDispose` / `disposeCallback` |

## Core Guarantees

- O(1) identity-based registration and lookup.
- LIFO disposal order.
- Idempotent `disposeAll()` / `disposeAutoDispose()` calls.
- Fail-safe cleanup: one disposal error is logged and remaining resources still release.
- Debug logging only in `kDebugMode`.

## License

MIT
