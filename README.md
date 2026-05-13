# auto_dispose_guard

Safe automatic disposal for Flutter controllers, streams, timers, and custom resources — across **every state-management pattern**.

AutoDisposeGuard removes repetitive `dispose()`, `close()`, and `cancel()` boilerplate while keeping cleanup idempotent, fail-safe, and crash-free.

---

## What's New in 1.0.3

- **`BlocAutoDisposeMixin`** — first-class Bloc, Cubit, and Riverpod `StateNotifier` support. No flutter_bloc or riverpod dependency needed.
- **`AutoDisposeChangeNotifier`** — extend instead of `ChangeNotifier`; registered resources auto-dispose when `dispose()` is called. Perfect for Provider and Riverpod.
- **`addDisposeListener(callback)`** — register a one-shot callback fired after all resources are released.
- **`isRegistered(resource)`** — check if a resource is already tracked before registering it.
- **`disposeOf(resource)`** — dispose a single resource early and remove it from tracking.
- **`unregister(resource)`** — remove a resource from tracking without disposing it.

---

## Installation

```yaml
dependencies:
  auto_dispose_guard: ^1.0.3
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

AutoDisposeGuard uses type checks, not reflection — zero overhead.

| Type | Auto-detected method |
|------|---------------------|
| `Disposable` (our interface) | `dispose()` |
| `Closeable` (our interface) | `close()` |
| `Cancellable` (our interface) | `cancel()` |
| `ChangeNotifier` | `dispose()` |
| `StreamController` | `close()` |
| `StreamSubscription` | `cancel()` |
| `Timer` | `cancel()` |
| Any other type | pass `onDispose` callback |

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

## License

MIT
