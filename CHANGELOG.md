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
