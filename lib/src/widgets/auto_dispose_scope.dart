import 'package:flutter/widgets.dart';

import 'package:auto_dispose_guard/src/core/dispose_registry.dart';
import 'package:auto_dispose_guard/src/core/lifecycle_manager.dart';

// ─── Public widget ────────────────────────────────────────────────────────────

/// Establishes a disposal scope for its widget subtree.
///
/// All resources registered within this scope — via [AutoDispose.of],
/// [AutoDisposeScope.of], or the `.autoDispose(context)` extension — are
/// automatically disposed when this widget is removed from the tree.
///
/// Typically placed at the top of a route or screen:
///
/// ```dart
/// MaterialPageRoute(
///   builder: (_) => const AutoDisposeScope(child: MyScreen()),
/// )
/// ```
///
/// Or wrapping a specific subtree that shares a set of resources:
///
/// ```dart
/// AutoDisposeScope(
///   debugLabel: 'FormSection',
///   child: FormSection(),
/// )
/// ```
class AutoDisposeScope extends StatefulWidget {
  const AutoDisposeScope({
    super.key,
    required this.child,
    this.debugLabel,
  });

  final Widget child;

  /// Optional label shown in debug logs. Defaults to `'AutoDisposeScope'`.
  final String? debugLabel;

  // ─── Static accessors ─────────────────────────────────────────────────────

  /// Returns the [DisposeRegistry] from the nearest [AutoDisposeScope] ancestor.
  ///
  /// Uses `getInheritedWidgetOfExactType` (not `dependOnInherited...`) so the
  /// caller is **not** registered as a rebuild dependent — safe to call from
  /// `initState` and `didChangeDependencies`.
  ///
  /// Throws a [FlutterError] when no ancestor scope exists.
  static DisposeRegistry of(BuildContext context) {
    final data = context.getInheritedWidgetOfExactType<_AutoDisposeScopeData>();
    if (data == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No AutoDisposeScope found in the widget tree.'),
        ErrorDescription(
          'AutoDisposeScope.of() was called with a BuildContext that does not '
          'contain an AutoDisposeScope ancestor.',
        ),
        ErrorHint(
          'Wrap the calling widget (or its route) with AutoDisposeScope:\n\n'
          '  AutoDisposeScope(\n'
          '    child: YourWidget(),\n'
          '  )',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return data.registry;
  }

  /// Returns the [DisposeRegistry] if an [AutoDisposeScope] exists, or `null`.
  static DisposeRegistry? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_AutoDisposeScopeData>()
        ?.registry;
  }

  @override
  State<AutoDisposeScope> createState() => _AutoDisposeScopeState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _AutoDisposeScopeState extends State<AutoDisposeScope> {
  late final LifecycleManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = LifecycleManager(
      debugLabel: widget.debugLabel ?? 'AutoDisposeScope',
    );
    _manager.bind();
  }

  @override
  void dispose() {
    _manager.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AutoDisposeScopeData(
      registry: _manager.registry,
      child: widget.child,
    );
  }
}

// ─── InheritedWidget ──────────────────────────────────────────────────────────

class _AutoDisposeScopeData extends InheritedWidget {
  const _AutoDisposeScopeData({
    required this.registry,
    required super.child,
  });

  final DisposeRegistry registry;

  // The registry instance never changes over the scope's lifetime, so no
  // descendant ever needs to rebuild because of this inherited widget.
  @override
  bool updateShouldNotify(_AutoDisposeScopeData old) => false;
}

// ─── Convenience accessor ─────────────────────────────────────────────────────

/// Convenience façade over [AutoDisposeScope] for imperative registration.
///
/// ```dart
/// AutoDispose.of(context).register(myController);
/// AutoDispose.of(context).register(myStream, disposeCallback: myStream.close);
/// ```
abstract final class AutoDispose {
  /// Returns the [DisposeRegistry] from the nearest [AutoDisposeScope].
  static DisposeRegistry of(BuildContext context) =>
      AutoDisposeScope.of(context);

  /// Returns the [DisposeRegistry] if an [AutoDisposeScope] exists, or `null`.
  static DisposeRegistry? maybeOf(BuildContext context) =>
      AutoDisposeScope.maybeOf(context);
}
