## 1.0.0

* Initial release.
* `AutoDisposeMixin` — zero-boilerplate State mixin; register resources inline with `register()`.
* `AutoDisposeScope` — InheritedWidget scope for shared cross-widget disposal.
* `AutoDispose.of(context)` — imperative registry accessor.
* `.autoDispose(context)` extension — fluent inline registration.
* `DisposeEngine` — auto-detects `dispose` / `close` / `cancel` without reflection.
* `DisposeRegistry` — O(1) identity map, LIFO disposal order, fail-safe error handling.
* `Disposable`, `Closeable`, `Cancellable` marker interfaces for custom types.
* Structured debug logging; zero overhead in release mode.
