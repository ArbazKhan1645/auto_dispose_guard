# auto_dispose_guard

**Zero-boilerplate, production-grade resource lifecycle management for Flutter.**

> Stop writing `dispose()` overrides. Stop tracking every controller manually.  
> Let the guard handle it — automatically, safely, with zero overhead in release builds.

---

## The Problem

Every Flutter developer has written this:

```dart
class _MyScreenState extends State<MyScreen> {
  late final _name      = TextEditingController();
  late final _email     = TextEditingController();
  late final _animation = AnimationController(vsync: this, ...);
  late final _focus     = FocusNode();
  late final _stream    = StreamController<int>();
  late final _sub       = _stream.stream.listen(...);

  @override
  void dispose() {
    _name.dispose();       // forget one → memory leak
    _email.dispose();
    _animation.dispose();
    _focus.dispose();
    _stream.close();       // close, not dispose!
    _sub.cancel();         // cancel, not dispose!
    super.dispose();
  }
}
```

Forgetting a single call causes memory leaks, frame drops, and
"used after dispose" crashes that are notoriously hard to track down.

---

## The Solution

```dart
class _MyScreenState extends State<MyScreen>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {

  late final _name      = register(TextEditingController());
  late final _email     = register(TextEditingController());
  late final _animation = register(AnimationController(vsync: this, ...));
  late final _focus     = register(FocusNode());
  late final _stream    = register(StreamController<int>());
  // ignore: unused_field
  late final _sub       = register(_stream.stream.listen(...));

  // ✅ No @override dispose() needed. Ever.
}
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       auto_dispose_guard                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌────────────────────┐     ┌────────────────────────────────┐  │
│   │  AutoDisposeMixin  │     │       AutoDisposeScope         │  │
│   │  (State mixin)     │     │  (InheritedWidget scope)       │  │
│   └─────────┬──────────┘     └────────────────┬───────────────┘  │
│             │                                 │                  │
│             └─────────────────┬───────────────┘                  │
│                               ▼                                  │
│                  ┌────────────────────────┐                      │
│                  │    LifecycleManager     │                      │
│                  └────────────┬───────────┘                      │
│                               │                                  │
│                               ▼                                  │
│                  ┌────────────────────────┐                      │
│                  │     DisposeRegistry     │  O(1) identity map   │
│                  │    (LinkedHashMap)      │  LIFO disposal       │
│                  └────────────┬───────────┘                      │
│                               │                                  │
│                               ▼                                  │
│                  ┌────────────────────────┐                      │
│                  │      DisposeEngine      │                      │
│                  │  Auto-detects method:  │                      │
│                  │  dispose / close /     │                      │
│                  │  cancel  (no mirrors)  │                      │
│                  └────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Installation

```yaml
dependencies:
  auto_dispose_guard: ^1.0.0
```

```dart
import 'package:auto_dispose_guard/auto_dispose_guard.dart';
```

---

## Usage

### Method 1 — `AutoDisposeMixin` (recommended)

Add the mixin to any `State` class and call `register()` on every resource.
No `dispose()` override needed.

```dart
class _ProfileScreenState extends State<ProfileScreen>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {

  late final _name   = register(TextEditingController());
  late final _email  = register(TextEditingController());
  late final _focus  = register(FocusNode());
  late final _anim   = register(
    AnimationController(vsync: this, duration: kThemeAnimationDuration),
  );
  late final _stream = register(StreamController<String>.broadcast());

  @override
  Widget build(BuildContext context) => ...;
}
```

> **Mixin order with TickerProviders:**  
> Place `AutoDisposeMixin` *after* ticker mixins so Flutter disposes the
> ticker before the `AnimationController`:
> ```dart
> with SingleTickerProviderStateMixin, AutoDisposeMixin  // ✅
> ```

---

### Method 2 — `AutoDisposeScope`

Wrap a route or subtree in `AutoDisposeScope`. Resources registered from
any descendant are disposed when the scope is removed from the tree.

```dart
// In your route builder:
MaterialPageRoute<void>(
  builder: (_) => const AutoDisposeScope(
    debugLabel: 'ProfileScreen',
    child: ProfileScreen(),
  ),
)
```

```dart
// From any descendant — safe to call from initState:
AutoDispose.of(context).register(myController);
```

---

### Method 3 — `.autoDispose()` extension

Fluent inline registration inside `initState` or `didChangeDependencies`
when a scope is present in the tree:

```dart
@override
void initState() {
  super.initState();
  _name   = TextEditingController().autoDispose(context);
  _stream = StreamController<int>().autoDispose(context);
  _focus  = FocusNode().autoDispose(context);
}
```

With a custom teardown:

```dart
_myService = MyService().autoDispose(
  context,
  onDispose: () => _myService.shutdown(),
);
```

---

## Auto-Detection Table

No reflection. Detection is pure `is` type checking — zero runtime cost.

| Type | Detected method | Common examples |
|------|-----------------|-----------------|
| `Disposable` (your interface) | `dispose()` | Custom BLoC, services |
| `ChangeNotifier` | `dispose()` | `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`, `PageController`, `TabController` |
| `StreamController` | `close()` | `StreamController<T>` |
| `StreamSubscription` | `cancel()` | `.stream.listen(...)` |
| `Timer` | `cancel()` | `Timer.periodic(...)` |
| `Closeable` (your interface) | `close()` | Custom streams |
| `Cancellable` (your interface) | `cancel()` | Custom tasks |
| Explicit `disposeCallback` | custom | Anything else |

---

## Custom Types

### Option A — implement a marker interface (zero-config)

```dart
class AnalyticsService implements Disposable {
  @override
  void dispose() { /* flush & teardown */ }
}

// Then register normally:
late final _analytics = register(AnalyticsService());
```

### Option B — provide an explicit callback

```dart
late final _db = register(
  Database.open(path),
  onDispose: () => _db.close(),
);
```

---

## Debug Intelligence

All output is in **debug mode only** (`kDebugMode`). Zero bytes of log code
execute in release builds.

**Normal disposal:**
```
✅ AutoDisposeGuard: Auto-disposed [TextEditingController]
✅ AutoDisposeGuard: Auto-disposed [AnimationController]
✅ AutoDisposeGuard: Auto-disposed [_BroadcastStreamController<String>]
[AutoDisposeGuard] Scope "ProfileScreen" released 3 resource(s)
```

**Unknown type warning:**
```
⚠️  AutoDisposeGuard Warning:
   Controller : SomeRandomClass
   Issue      : No disposal method detected (dispose / close / cancel)
   Action     : Object skipped. Implement Disposable, Closeable, Cancellable,
                or pass a disposeCallback.
```

**Disposal error (fail-safe):**
```
❌ AutoDisposeGuard Error:
   Resource : AnimationController
   Error    : Null check operator used on a null value
   Trace    : ...
```
Disposal continues for all remaining resources — one failure never blocks the rest.

---

## Performance

| Metric | Value |
|--------|-------|
| Registration | O(1) — identity hash map (`LinkedHashMap`) |
| Lookup | O(1) |
| Disposal | O(n) — unavoidable minimum |
| Widget rebuilds triggered | **Zero** — `updateShouldNotify` always returns `false` |
| Listener overhead | **Zero** — no streams, no `ChangeNotifier` internally |
| Release-build log overhead | **Zero** — all guarded by `kDebugMode` |
| Memory per tracked resource | ~56 bytes (`TrackedResource` object) |

---

## API Reference

### `AutoDisposeMixin`

```dart
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T>
```

| Member | Description |
|--------|-------------|
| `R register<R>(R resource, {void Function()? onDispose})` | Registers resource; returns it for inline `late final` assignment |
| `DisposeRegistry disposeRegistry` | Direct registry access for advanced use |

---

### `AutoDisposeScope`

```dart
class AutoDisposeScope extends StatefulWidget
```

| Member | Description |
|--------|-------------|
| `AutoDisposeScope.of(context)` | Returns nearest `DisposeRegistry`; throws if none |
| `AutoDisposeScope.maybeOf(context)` | Returns nearest `DisposeRegistry` or `null` |
| `debugLabel` | Optional label for debug output |

---

### `AutoDispose`

Convenience façade — identical behaviour to `AutoDisposeScope`:

```dart
AutoDispose.of(context).register(controller);
AutoDispose.of(context).register(obj, disposeCallback: obj.teardown);
```

---

### `DisposeRegistry`

| Member | Description |
|--------|-------------|
| `register(object, {disposeCallback})` | Register a resource |
| `unregister(object)` | Remove without disposing |
| `disposeResource(object)` | Dispose and remove immediately |
| `disposeAll()` | Dispose all (LIFO); called automatically |
| `isRegistered(object)` | Query registration state |
| `resourceCount` | Number of tracked resources |
| `isDisposed` | Whether `disposeAll()` has been called |

---

### Marker interfaces

```dart
abstract interface class Disposable { void dispose(); }
abstract interface class Closeable  { void close();   }
abstract interface class Cancellable { void cancel(); }
```

---

## Before vs After

**Before** (6 resources, 6 manual calls, 1 typo away from a leak):
```dart
@override
void dispose() {
  _nameController.dispose();
  _emailController.dispose();
  _animation.dispose();
  _focusNode.dispose();
  _counterStream.close();  // different method name!
  _subscription.cancel();  // yet another!
  super.dispose();
}
```

**After** (6 resources, 0 manual calls):
```dart
// Nothing. The mixin handles everything.
```

---

## License

MIT
