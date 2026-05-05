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
    _autoDisposeManager =
        LifecycleManager(debugLabel: runtimeType.toString());
    _autoDisposeManager.bind();
  }

  @override
  void dispose() {
    // super.dispose() runs first so that TickerProvider mixins can clean up
    // their tickers before AnimationController.dispose() is invoked below.
    super.dispose();
    _autoDisposeManager.release();
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
  R register<R extends Object>(R resource, {void Function()? onDispose}) {
    disposeRegistry.register(resource, disposeCallback: onDispose);
    return resource;
  }
}
