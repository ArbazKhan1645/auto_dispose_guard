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
