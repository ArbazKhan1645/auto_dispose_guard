# auto_dispose_guard

[![CI](https://github.com/ArbazKhan1645/auto_dispose_guard/actions/workflows/ci.yml/badge.svg)](https://github.com/ArbazKhan1645/auto_dispose_guard/actions/workflows/ci.yml)
[![coverage](https://img.shields.io/badge/coverage-%E2%89%A580%25-brightgreen)](https://github.com/ArbazKhan1645/auto_dispose_guard/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/auto_dispose_guard.svg)](https://pub.dev/packages/auto_dispose_guard)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Safe automatic disposal for Flutter controllers, streams, timers, and custom resources — across **every state-management pattern**.

AutoDisposeGuard removes repetitive `dispose()`, `close()`, and `cancel()` boilerplate while keeping cleanup idempotent, fail-safe, and crash-free.

---

## What's New in 1.0.4

- **Flutter-Recommended Teardown Ordering** — Reordered mixin cleanup to release registered resources *before* framework teardown (`super.dispose()`), ensuring ticker-dependent resources like `AnimationController` dispose cleanly.
- **Dynamic Duck-Type Detection** — Probes standard teardown methods (`dispose()`, `close()`, `cancel()`) and status indicators (`isDisposed`, `isClosed`) using dynamic member access (reflection-free).
- **Sink Support** — Native auto-disposal for standard `Sink` interfaces, mapped automatically to `close()`.
- **Mounted Callback Guards** — Adds `safeExecute()` and `safeExecuteAsync()` to `AutoDisposeMixin` to protect async callbacks (e.g. `setState`) post-unmount.
- **Retryable Disposals** — Gracefully handles individual resource disposal errors via try/catch, allowing later retries without marking the resource as disposed on failure.

---

## Installation

```yaml
dependencies:
  auto_dispose_guard: ^1.0.4
```

```dart
import 'package:auto_dispose_guard/auto_dispose_guard.dart';
```

---

## API At a Glance

| API | Best for |
|-----|----------|
| `AutoDisposeMixin` | `State` classes — register resources inline |
| `AutoDisposeScope` | Widget-tree scope for shared cross-widget resources |
| `AutoDispose.of(context)` | Imperative registration from any widget |
| `.autoDispose(context)` | Fluent one-liner registration |
| `AutoDisposeBag` | Plain Dart classes, repositories, services |
| `AutoDisposeBagMixin` | GetX, Provider / ChangeNotifier lifecycle owners |
| `BlocAutoDisposeMixin` | Bloc, Cubit, Riverpod StateNotifier |
| `AutoDisposeChangeNotifier` | Provider models, Riverpod ChangeNotifier notifiers |

---

## Widget State (AutoDisposeMixin)

```dart
class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {

  late final name      = register(TextEditingController());
  late final focus     = register(FocusNode());
  late final animation = register(
    AnimationController(vsync: this, duration: kThemeAnimationDuration),
  );
  late final stream    = register(StreamController<String>.broadcast());

  @override
  Widget build(BuildContext context) => const SizedBox();

  // No dispose() override needed.
}
```

### Extra shortcuts on AutoDisposeMixin

```dart
// Dispose one resource early (e.g. when a tab closes):
disposeOf(animation);

// Remove from tracking without disposing (take back ownership):
unregister(stream);

// Check before re-registering:
if (!isRegistered(stream)) register(stream);

// Be notified when this State's scope fully closes:
addDisposeListener(() => debugPrint('screen cleaned up'));
```

---

## Bloc / Cubit (flutter_bloc)

No flutter_bloc dependency is added to your project — `BlocAutoDisposeMixin` works with any version.

```dart
class SearchCubit extends Cubit<SearchState> with BlocAutoDisposeMixin {
  SearchCubit(this._repo) : super(const SearchState()) {
    _sub = register(
      _repo.stream.listen(_onData),
      isDisposed: () => isClosed,   // skip if cubit already closed
    );
    _debounce = register(
      Timer(const Duration(milliseconds: 300), () {}),
    );
  }

  final DataRepository _repo;
  late final StreamSubscription<Data> _sub;
  late final Timer _debounce;

  @override
  Future<void> close() {
    disposeAutoDispose();   // ← release registered resources first
    return super.close();
  }
}
```

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> with BlocAutoDisposeMixin {
  AuthBloc(this._auth) : super(AuthInitial()) {
    _tokenSub = register(_auth.tokenStream.listen(_onToken));
    on<LogoutEvent>(_onLogout);
  }

  final AuthService _auth;
  late final StreamSubscription<Token> _tokenSub;

  @override
  Future<void> close() {
    disposeAutoDispose();
    return super.close();
  }
}
```

---

## Riverpod — StateNotifier

```dart
class CartNotifier extends StateNotifier<CartState> with BlocAutoDisposeMixin {
  CartNotifier(this._repo) : super(const CartState()) {
    _timer = register(
      Timer.periodic(const Duration(minutes: 5), (_) => _sync()),
    );
    _sub = register(_repo.cartStream.listen(_onCart));
  }

  final CartRepository _repo;
  late final Timer _timer;
  late final StreamSubscription<Cart> _sub;

  @override
  void dispose() {
    disposeAutoDispose();   // ← release registered resources first
    super.dispose();
  }
}
```

---

## Provider / ChangeNotifier (AutoDisposeChangeNotifier)

Extend `AutoDisposeChangeNotifier` instead of `ChangeNotifier`. All registered resources are disposed automatically — no override needed.

```dart
class CartModel extends AutoDisposeChangeNotifier {
  late final search = register(TextEditingController());
  late final scroll = register(ScrollController());
  late final _timer = register(
    Timer.periodic(const Duration(seconds: 30), (_) => _sync()),
  );

  void _sync() { /* fetch latest cart */ }

  // dispose() is handled automatically.
}
```

```dart
// With Provider:
ChangeNotifierProvider(create: (_) => CartModel())
```

Custom teardown is still possible:

```dart
@override
void dispose() {
  _socket.close();   // run before listeners are notified
  super.dispose();   // calls disposeAutoDispose() + ChangeNotifier.dispose()
}
```

---

## GetX Controllers and Services

```dart
class LoginController extends GetxController with AutoDisposeBagMixin {
  late final email    = register(TextEditingController());
  late final password = register(TextEditingController());
  late final timer    = register(
    Timer.periodic(const Duration(seconds: 1), (_) => _tick()),
  );

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

---

## Plain Dart Classes (AutoDisposeBag)

```dart
class DataRepository {
  DataRepository() : _bag = AutoDisposeBag(debugLabel: 'DataRepository');

  final AutoDisposeBag _bag;

  late final events  = _bag.register(StreamController<int>.broadcast());
  late final _timer  = _bag.register(
    Timer.periodic(const Duration(seconds: 10), (_) => _heartbeat()),
  );

  bool get isReady => !_bag.isDisposed;

  void dispose() => _bag.dispose();
}
```

---

## Widget-Tree Scope (AutoDisposeScope)

Wrap a route or subtree once, register from any descendant.

```dart
MaterialPageRoute<void>(
  builder: (_) => const AutoDisposeScope(
    debugLabel: 'ProfileRoute',
    child: ProfileScreen(),
  ),
);
```

```dart
// In any descendant widget's initState / didChangeDependencies:
final controller = TextEditingController().autoDispose(context);
AutoDispose.of(context).register(StreamController<int>());
```

---

## Lifecycle Hooks

```dart
class _HomeState extends State<HomeScreen> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    addDisposeListener(() {
      // Fires after every resource in this scope has been released.
      analytics.logEvent('home_screen_cleaned_up');
    });
  }
}
```

---

## Already-Disposed Guards

Pass an `isDisposed` probe to prevent double-dispose crashes.

```dart
late final socket = register(
  MySocket(),
  onDispose: () => socket.close(),
  isDisposed: () => socket.isClosed,
);
```

Implement `DisposeState` on your own types:

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

---

## Auto-Detection Table

AutoDisposeGuard uses type checks first, then safe dynamic probing as a fallback — zero reflection overhead.

| Type | Auto-detected method | Disposed probe |
|------|---------------------|----------------|
| `Disposable` (our interface) | `dispose()` | — |
| `Closeable` (our interface) | `close()` | — |
| `Cancellable` (our interface) | `cancel()` | — |
| `DisposeState` (our interface) | — | `isDisposed` |
| `ChangeNotifier` | `dispose()` | dynamic `isDisposed` |
| `StreamController` | `close()` | `isClosed` |
| `StreamSubscription` | `cancel()` | — |
| `Timer` | `cancel()` | `!isActive` |
| `Sink` | `close()` | — |
| Duck-type fallback | dynamic `dispose()` / `close()` / `cancel()` | dynamic `isDisposed` / `isClosed` |
| Any other type | pass `onDispose` callback | pass `isDisposed` callback |

For Bloc/Cubit (which have `close()` but do not implement our `Closeable`):

```dart
// Explicit callback — works with any framework type:
register(myCubit, onDispose: () => myCubit.close());

// Or use BlocAutoDisposeMixin directly in the Cubit class.
```

---

## Core Guarantees

- **O(1)** identity-based registration and lookup.
- **LIFO** disposal order — last registered, first released.
- **Idempotent** — `disposeAll()` / `disposeAutoDispose()` are safe to call multiple times.
- **Fail-safe** — one disposal error is logged; remaining resources still release.
- **Zero overhead in release builds** — all debug logging is guarded by `kDebugMode`.

---

## Production & Enterprise Semantics

### 1. `super.dispose()` Teardown Order

> **⚠️ DO NOT change this order.** AutoDispose resources are released **before** `super.dispose()` to support `AnimationController` / Ticker lifecycles.

`AutoDisposeMixin` intentionally invokes `_autoDisposeManager.release()` **before** delegating to `super.dispose()`. This matches the recommended own-cleanup-first pattern in Flutter.

* **Why**: Dart mixins evaluate right-to-left. By executing mixin cleanup first, resources like `AnimationController` can cleanly shut down while the vsync/ticker providers are still fully active.
* **Mixin ordering**: Always place `AutoDisposeMixin` **after** `SingleTickerProviderStateMixin` / `TickerProviderStateMixin` in the `with` clause so the disposal chain runs in the correct order.
* **Future maintainers**: Inverting this order will cause `TickerProvider` assertion errors with `AnimationController`. This is by design, not accidental.

### 2. Strong Reference Retention Design
Resources are held via a `LinkedHashMap<Object, TrackedResource>` with identity equality — **strong references by design**.

* **Why not WeakReference?** Weak references are garbage-collected non-deterministically. If the GC collects an active resource prematurely, its `dispose()` / `close()` hook is never called, causing native memory leaks. Strong retention guarantees deterministic cleanup.
* **Avoid memory growth**: Only register resources inside lifecycle initialization methods (`initState`, constructor) and **never** inside `build()`. Long-lived scopes with accidental build-time registrations will leak.

### 3. Hot Reload & Duplicate Protection
During development, Hot Reload cycles can trigger duplicate registration paths. AutoDisposeGuard uses identity checks (`identical`) in O(1) to make duplicate registration a fast, safe no-op. Stale closures or redundant controllers are avoided.

> **Note**: Hot Reload validation requires manual QA — automated hot-reload testing is not reliably supported in `flutter test`.

### 4. Error Isolation & Retry Semantics
If a resource's `dispose()` / `close()` throws:
- The `TrackedResource` remains in a **non-disposed** state (`_disposed = false`), allowing retry.
- The registry's `disposeAll()` catches the error, logs it, and **continues** disposing remaining resources — one failure never blocks the rest.

```dart
// TrackedResource internals:
try {
  _disposeFn();
  _disposed = true;
} catch (_) {
  // _disposed stays false — caller can retry
  rethrow;
}
```

### 5. Enterprise Leak Tracking
For enterprise-scale validation, we recommend integrating manual QA or the official `leak_tracker` package during integration test suites:

```dart
testWidgets('no controller leaks', (tester) async {
  final controller = TextEditingController();
  // Register, use, and let AutoDispose handle cleanup.
  // Then assert controller state or use leak_tracker.
});
```

### 6. Benchmark Performance
Performance is verified under high loads (10,000 resources). Measured on CI:

| Operation | Throughput | Complexity |
|-----------|-----------|------------|
| Registration | < 0.2 μs/op | O(1) identity hash |
| Disposal | < 0.1 μs/op | O(1) reverse LIFO |
| Duplicate check | < 0.05 μs/op | O(1) hash lookup |
| 1K TextEditingControllers | ~35 ms register, ~3 ms dispose | Linear |
| 1K bag lifecycles (10 resources each) | ~15 ms | Linear |

---

## Compatibility Matrix

| Environment | Supported Version |
|-------------|-------------------|
| **Flutter SDK** | `>= 3.10.0` (including Flutter 3.22+) |
| **Dart SDK** | `>= 3.0.0 < 4.0.0` |
| **Platforms** | Android, iOS, Web, macOS, Windows, Linux |
| **State Management** | Bloc, Cubit, Riverpod, Provider, GetX, vanilla |

---

## CI Pipeline

Every push and PR runs the full validation suite via GitHub Actions:

```
✅ dart format --set-exit-if-changed
✅ flutter analyze
✅ flutter test --coverage
✅ Coverage gate ≥ 80%
```

---

## License

MIT
