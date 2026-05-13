import 'package:auto_dispose_guard/src/core/dispose_registry.dart';

/// A framework-agnostic owner for disposable resources.
///
/// Use this in GetX controllers/services, Provider objects, repositories,
/// blocs, or any plain Dart class where a Flutter [State] mixin is not
/// available.
final class AutoDisposeBag {
  AutoDisposeBag({String debugLabel = 'AutoDisposeBag'})
      : registry = DisposeRegistry(debugLabel: debugLabel);

  /// Direct access to the underlying registry for advanced operations.
  final DisposeRegistry registry;

  /// Whether this bag has already released its resources.
  bool get isDisposed => registry.isDisposed;

  /// Number of resources currently tracked.
  int get resourceCount => registry.resourceCount;

  /// Registers [resource] and returns it for inline assignment.
  ///
  /// [onDispose] overrides the auto-detected teardown method.
  /// [isDisposed] can be supplied when the object can be manually disposed
  /// elsewhere and should be skipped during bag cleanup.
  R register<R extends Object>(
    R resource, {
    void Function()? onDispose,
    bool Function()? isDisposed,
  }) {
    registry.register(
      resource,
      disposeCallback: onDispose,
      isDisposed: isDisposed,
    );
    return resource;
  }

  /// Removes [resource] without disposing it.
  void unregister(Object resource) => registry.unregister(resource);

  /// Disposes one registered resource immediately.
  void disposeResource(Object resource) => registry.disposeResource(resource);

  /// Disposes all registered resources. Safe to call more than once.
  void dispose() => registry.disposeAll();
}

/// Adds AutoDisposeGuard registration to any non-widget lifecycle owner.
///
/// In GetX, call [disposeAutoDispose] from `onClose()`.
/// In Provider/ChangeNotifier, call it from `dispose()`.
mixin AutoDisposeBagMixin {
  late final AutoDisposeBag autoDisposeBag = AutoDisposeBag(
    debugLabel: runtimeType.toString(),
  );

  /// Direct access to the backing registry for advanced operations.
  DisposeRegistry get disposeRegistry => autoDisposeBag.registry;

  /// Whether [disposeAutoDispose] has already released this mixin's resources.
  bool get isAutoDisposeDisposed => autoDisposeBag.isDisposed;

  /// Registers [resource] and returns it for inline assignment.
  R register<R extends Object>(
    R resource, {
    void Function()? onDispose,
    bool Function()? isDisposed,
  }) {
    return autoDisposeBag.register(
      resource,
      onDispose: onDispose,
      isDisposed: isDisposed,
    );
  }

  /// Disposes all resources registered by this owner.
  ///
  /// Safe to call multiple times, including when a base class lifecycle method
  /// is also invoked.
  void disposeAutoDispose() => autoDisposeBag.dispose();
}
