/// **auto_dispose_guard** — Zero-boilerplate resource lifecycle management
/// for production-scale Flutter applications.
///
/// ## Core entry points
///
/// | API | When to use |
/// |-----|-------------|
/// | [AutoDisposeMixin] | Preferred — adds `register()` directly to a `State` class |
/// | [AutoDisposeScope] | Widget-tree scope for cross-widget resource sharing |
/// | [AutoDispose] | Imperative accessor: `AutoDispose.of(context).register(x)` |
/// | `.autoDispose(context)` | Inline extension for fluent initialization |
///
/// ## Marker interfaces (implement for custom types)
///
/// | Interface | Method |
/// |-----------|--------|
/// | [Disposable] | `void dispose()` |
/// | [Closeable]  | `void close()` |
/// | [Cancellable]| `void cancel()` |
library auto_dispose_guard;

// Marker interfaces + engine (advanced / testing use)
export 'src/core/dispose_engine.dart'
    show Cancellable, Closeable, Disposable, DisposeEngine;

// Registry (advanced use)
export 'src/core/dispose_registry.dart' show DisposeRegistry;

// Primary mixin API
export 'src/mixins/auto_dispose_mixin.dart' show AutoDisposeMixin;

// Widget-tree scope API
export 'src/widgets/auto_dispose_scope.dart' show AutoDispose, AutoDisposeScope;

// Inline extension API
export 'src/extensions/dispose_extension.dart' show AutoDisposeExtension;
