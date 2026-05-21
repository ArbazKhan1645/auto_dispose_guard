## 1.0.4

### Production Hardening & Safety Helpers

* **Flutter-Recommended Teardown Ordering** — Reordered `AutoDisposeMixin.dispose()` to invoke `_autoDisposeManager.release()` *before* delegating to `super.dispose()`. This guarantees that state-dependent objects (such as `AnimationController`) are disposed while the framework's own teardown mechanics are still fully intact.
- **Dynamic Duck-Type Detection & Resilient Resolution** — Expanded `DisposeEngine` to dynamically probe for standard teardown methods (`dispose`, `close`, `cancel`) and state getters (`isDisposed`, `isClosed`) using dynamic member access. This allows auto-disposal of third-party classes (such as BloCs and custom controllers) without needing explicit subclassing or marker interfaces.
- **Sink Support** — Added out-of-the-box auto-disposal for standard `Sink` objects, mapping them to `close()`.
* **Mounted Callback Guards (`safeExecute` / `safeExecuteAsync`)** — Added safety helper methods in `AutoDisposeMixin` to guard synchronous and asynchronous state modifications (such as `setState`), safely skipping invocation if the widget is no longer `mounted`.
* **Retryable Resource Disposal** — Re-engineered `TrackedResource` to support try/catch isolation so that a failed disposal leaves the resource in a non-disposed state, allowing the parent registry to safely retry disposal later.
- **Comprehensive Testing Suite** — Introduced a rigorous suite of integration, stress, and benchmark tests under `test/`:
  - `stress_test.dart`: Validates massive registration storms, concurrent modifications, and navigation cycling.
  - `animation_controller_test.dart`: Assures leak-free teardowns for running `AnimationController` loops.
  - `async_safety_test.dart`: Tests `safeExecute` guards post-disposal.
  - `edge_case_test.dart`: Validates fail-safe error isolation, nested scopes, and type fallbacks.
  - `benchmark_test.dart`: Gates registration and disposal operations at < 1.5μs per op, demonstrating O(1) scaling.
- **CI Pipeline** — GitHub Actions now runs `dart format`, `flutter analyze`, `flutter test --coverage`, and enforces ≥ 80% code coverage on every push and PR.
- **README Overhaul** — Added coverage badge, pub.dev badge, license badge, expanded auto-detection table (Sink, duck-type fallback, disposed probes), detailed error isolation & retry semantics docs, benchmark performance table, platform/state-management compatibility matrix, and explicit `super.dispose()` order warning for future contributors.

## 1.0.3

### New APIs

* **`BlocAutoDisposeMixin`** — dedicated mixin for Bloc, Cubit, and Riverpod `StateNotifier`. No flutter_bloc or riverpod dependency required. Call `disposeAutoDispose()` from your `close()` / `dispose()` override and all registered resources are released safely.
* **`AutoDisposeChangeNotifier`** — abstract ChangeNotifier subclass that auto-disposes registered resources when `dispose()` is called. Drop-in for Provider models and Riverpod `ChangeNotifier`-based notifiers.
* **`addDisposeListener(callback)`** on `DisposeRegistry`, `AutoDisposeBag`, `AutoDisposeBagMixin`, `BlocAutoDisposeMixin`, and `AutoDisposeMixin` — register a one-shot callback invoked after all resources are released. Useful for notifying parent objects, logging, or running teardown logic that depends on children being disposed first.
* **`isRegistered(resource)`** on `AutoDisposeBag`, `AutoDisposeBagMixin`, and `AutoDisposeMixin` — query whether a resource is currently tracked before registering or disposing it.
* **`disposeOf(resource)`** on `AutoDisposeMixin` and `BlocAutoDisposeMixin` — dispose a single resource immediately and remove it from tracking.
* **`unregister(resource)`** on `AutoDisposeMixin` and `BlocAutoDisposeMixin` — remove a resource from tracking without disposing it; use when taking back ownership of a resource's lifecycle.

### Stability & Safety

* All new methods are idempotent and fail-safe: calling `disposeAutoDispose()` or `addDisposeListener()` after disposal is guarded by a debug-mode assertion and is a no-op in release builds.
* `addDisposeListener` callbacks execute after all resources are released and are themselves wrapped in try/catch so a listener error cannot suppress cleanup logging.

## 1.0.2

* Added `AutoDisposeBag` for plain Dart classes, repositories, blocs, services, and state-management controllers.
* Added `AutoDisposeBagMixin` so GetX controllers/services and Provider classes can use `register()` outside widget `State`.
* Added `DisposeState` and `isDisposed` probes to skip already disposed resources before teardown.
* Added built-in disposed-state checks for `StreamController` and `Timer`.
* Improved registry stability for double-dispose scenarios while keeping disposal idempotent and fail-safe.
* Updated README with GetX, Provider, service, bag, scope, and disposed-guard examples.
* Updated example app to demonstrate controller/service style cleanup.
* Shortened `pubspec.yaml` description to satisfy pub.dev package-description scoring.

## 1.0.1

* Fix: updated repository and homepage URLs in pubspec.yaml.

## 1.0.0

* Initial release.
* `AutoDisposeMixin` - zero-boilerplate State mixin; register resources inline with `register()`.
* `AutoDisposeScope` - InheritedWidget scope for shared cross-widget disposal.
* `AutoDispose.of(context)` - imperative registry accessor.
* `.autoDispose(context)` extension - fluent inline registration.
* `DisposeEngine` - auto-detects `dispose` / `close` / `cancel` without reflection.
* `DisposeRegistry` - O(1) identity map, LIFO disposal order, fail-safe error handling.
* `Disposable`, `Closeable`, `Cancellable` marker interfaces for custom types.
* Structured debug logging; zero overhead in release mode.
