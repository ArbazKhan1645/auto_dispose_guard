import 'package:flutter/widgets.dart';

import 'package:auto_dispose_guard/src/core/dispose_registry.dart';
import 'package:auto_dispose_guard/src/core/lifecycle_manager.dart';

/// Mixin that wires [DisposeRegistry] auto-disposal directly into a [State].
///
/// Use this when a screen or component manages its own resources and does not
/// need a shared [AutoDisposeScope] in the widget tree.
///
/// **Zero boilerplate:** override neither `initState` nor `dispose` unless
/// you have other work to do there.
///
/// ```dart
/// class _ProfileScreenState extends State<ProfileScreen>
///     with AutoDisposeMixin, SingleTickerProviderStateMixin {
///
///   // Registered and auto-disposed — no dispose() override needed.
///   late final _name   = register(TextEditingController());
///   late final _email  = register(TextEditingController());
///   late final _focus  = register(FocusNode());
///   late final _anim   = register(
///     AnimationController(vsync: this, duration: kThemeAnimationDuration),
///   );
///   late final _stream = register(StreamController<String>.broadcast());
///
///   @override
///   Widget build(BuildContext context) => ...;
/// }
/// ```
///
/// ### Mixin ordering with TickerProviders
///
/// When combining with `SingleTickerProviderStateMixin` or
/// `TickerProviderStateMixin`, place `AutoDisposeMixin` **after** the ticker
/// mixin so that `super.dispose()` (which cleans up the ticker) runs before
/// `AnimationController.dispose()`:
///
/// ```dart
/// with SingleTickerProviderStateMixin, AutoDisposeMixin  // ✅ correct
/// with AutoDisposeMixin, SingleTickerProviderStateMixin  // ⚠️  works but may log a benign error
/// ```
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T> {
  late final LifecycleManager _autoDisposeManager;

  /// Direct access to the backing registry.
  ///
  /// Prefer [register] for routine use; access this only for advanced
  /// operations like [DisposeRegistry.unregister] or [DisposeRegistry.disposeResource].
  DisposeRegistry get disposeRegistry => _autoDisposeManager.registry;

  @override
  void initState() {
    super.initState();
    _autoDisposeManager = LifecycleManager(debugLabel: runtimeType.toString());
    _autoDisposeManager.bind();
  }

  @override
  void dispose() {
    // Release registered resources *before* super.dispose() — this is the
    // Flutter-recommended pattern (own cleanup first, then framework teardown).
    //
    // When combining with TickerProviderStateMixin, place AutoDisposeMixin
    // *after* the ticker mixin in the `with` clause.  Dart calls `dispose()`
    // on the *last* mixin first, so AutoDisposeMixin.dispose() runs before
    // TickerProviderStateMixin.dispose(), giving controllers a chance to be
    // disposed while the ticker is still valid.
    _autoDisposeManager.release();
    super.dispose();
  }

  /// Registers [resource] with this scope and returns it for inline use.
  ///
  /// [onDispose] overrides the auto-detected teardown — use for resources
  /// that have a custom cleanup signature (e.g. a non-standard `teardown()`).
  ///
  /// ```dart
  /// late final _timer = register(
  ///   Timer.periodic(const Duration(seconds: 1), _onTick),
  /// );
  /// ```
  R register<R extends Object>(
    R resource, {
    void Function()? onDispose,
    bool Function()? isDisposed,
  }) {
    disposeRegistry.register(
      resource,
      disposeCallback: onDispose,
      isDisposed: isDisposed,
    );
    return resource;
  }

  /// Returns `true` if [resource] is currently tracked by this scope.
  bool isRegistered(Object resource) => disposeRegistry.isRegistered(resource);

  /// Removes [resource] from tracking **without** disposing it.
  ///
  /// Use when you want to take ownership of disposal back from the scope.
  void unregister(Object resource) => disposeRegistry.unregister(resource);

  /// Disposes [resource] immediately and removes it from tracking.
  ///
  /// No-op if [resource] is not registered or already disposed.
  void disposeOf(Object resource) => disposeRegistry.disposeResource(resource);

  /// Registers [callback] to be called once after this scope's [dispose] completes.
  void addDisposeListener(void Function() callback) =>
      disposeRegistry.addDisposeListener(callback);

  /// Executes [callback] only if the widget is still [mounted].
  ///
  /// Use this to guard async callbacks that may fire after disposal:
  /// ```dart
  /// await Future.delayed(const Duration(seconds: 1));
  /// safeExecute(() => setState(() => _loaded = true));
  /// ```
  void safeExecute(VoidCallback callback) {
    if (mounted) callback();
  }

  /// Async version of [safeExecute].
  ///
  /// ```dart
  /// safeExecuteAsync(() async {
  ///   final data = await api.fetch();
  ///   setState(() => _data = data);
  /// });
  /// ```
  Future<void> safeExecuteAsync(Future<void> Function() callback) async {
    if (mounted) await callback();
  }
}
