import 'package:auto_dispose_guard/src/core/dispose_registry.dart';
import 'package:auto_dispose_guard/src/utils/logger.dart';

/// Couples a [DisposeRegistry] to a widget's `State` lifecycle.
///
/// Created once per scope (in `initState` or via a mixin), released once
/// in `dispose`. Not meant to be used directly — prefer [AutoDisposeMixin]
/// or [AutoDisposeScope].
final class LifecycleManager {
  LifecycleManager({String debugLabel = 'unnamed'})
      : registry = DisposeRegistry(debugLabel: debugLabel);

  /// The registry that accumulates resources for this scope.
  final DisposeRegistry registry;

  bool _bound = false;

  /// Called during `State.initState` to activate the manager.
  void bind() {
    assert(!_bound, 'LifecycleManager.bind() called more than once.');
    _bound = true;
    AutoDisposeLogger.info(registry.debugLabel, 'lifecycle bound');
  }

  /// Called during `State.dispose` to release all tracked resources.
  void release() {
    assert(_bound, 'LifecycleManager.release() called before bind().');
    registry.disposeAll();
  }
}
