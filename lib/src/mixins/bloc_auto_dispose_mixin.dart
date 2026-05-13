import 'package:auto_dispose_guard/src/core/auto_dispose_bag.dart';
import 'package:auto_dispose_guard/src/core/dispose_registry.dart';

/// Adds zero-boilerplate resource tracking to Bloc, Cubit, StateNotifier,
/// or any plain-Dart class with a `close()` / `dispose()` lifecycle.
///
/// AutoDisposeGuard has **no dependency on flutter_bloc or riverpod** — this
/// mixin detects nothing at compile time and integrates with any framework.
///
/// ---
///
/// ## Bloc / Cubit (flutter_bloc)
///
/// ```dart
/// class SearchCubit extends Cubit<SearchState> with BlocAutoDisposeMixin {
///   SearchCubit() : super(const SearchState()) {
///     _timer = register(
///       Timer.periodic(const Duration(seconds: 5), (_) => _poll()),
///     );
///     _sub = register(
///       _repository.stream.listen(_onData),
///     );
///   }
///
///   late final Timer _timer;
///   late final StreamSubscription<Data> _sub;
///
///   @override
///   Future<void> close() {
///     disposeAutoDispose(); // ← dispose registered resources first
///     return super.close();
///   }
/// }
/// ```
///
/// ## Riverpod — StateNotifier
///
/// ```dart
/// class CounterNotifier extends StateNotifier<int> with BlocAutoDisposeMixin {
///   CounterNotifier() : super(0) {
///     _timer = register(
///       Timer.periodic(const Duration(seconds: 1), (_) => state++),
///     );
///   }
///
///   late final Timer _timer;
///
///   @override
///   void dispose() {
///     disposeAutoDispose(); // ← dispose registered resources first
///     super.dispose();
///   }
/// }
/// ```
///
/// ## GetX — GetxController / GetxService
///
/// Prefer [AutoDisposeBagMixin] for GetX (it is identical); use this mixin
/// when the Bloc naming convention feels more natural in your team.
///
/// ---
///
/// ### Safe double-dispose
///
/// [disposeAutoDispose] is idempotent — calling it more than once (e.g. from
/// both `close()` and a `dispose()` override) is always safe and produces no
/// side effects after the first call.
mixin BlocAutoDisposeMixin {
  late final AutoDisposeBag _blocBag = AutoDisposeBag(
    debugLabel: runtimeType.toString(),
  );

  /// Direct access to the underlying registry for advanced operations such as
  /// [DisposeRegistry.unregister] or [DisposeRegistry.disposeResource].
  DisposeRegistry get disposeRegistry => _blocBag.registry;

  /// Whether [disposeAutoDispose] has already been called.
  bool get isAutoDisposeDisposed => _blocBag.isDisposed;

  /// Number of resources currently tracked.
  int get resourceCount => _blocBag.resourceCount;

  /// Returns `true` if [resource] is currently registered.
  bool isRegistered(Object resource) => _blocBag.isRegistered(resource);

  /// Registers [resource] and returns it for inline assignment.
  ///
  /// [onDispose] overrides the auto-detected teardown method.
  /// [isDisposed] lets AutoDisposeGuard skip resources already cleaned up
  /// elsewhere, preventing double-dispose crashes.
  ///
  /// ```dart
  /// late final _sub = register(
  ///   bloc.stream.listen(_onState),
  ///   isDisposed: () => isClosed,
  /// );
  /// ```
  R register<R extends Object>(
    R resource, {
    void Function()? onDispose,
    bool Function()? isDisposed,
  }) =>
      _blocBag.register(resource, onDispose: onDispose, isDisposed: isDisposed);

  /// Removes [resource] from tracking **without** disposing it.
  void unregister(Object resource) => _blocBag.unregister(resource);

  /// Disposes [resource] immediately and removes it from tracking.
  void disposeOf(Object resource) => _blocBag.disposeResource(resource);

  /// Registers [callback] to be invoked once after [disposeAutoDispose] finishes.
  void addDisposeListener(void Function() callback) =>
      _blocBag.addDisposeListener(callback);

  /// Disposes all resources registered by this mixin.
  ///
  /// Call this from your [Bloc.close] or [StateNotifier.dispose] override
  /// **before** calling `super`:
  ///
  /// ```dart
  /// @override
  /// Future<void> close() {
  ///   disposeAutoDispose();
  ///   return super.close();
  /// }
  /// ```
  void disposeAutoDispose() => _blocBag.dispose();
}
