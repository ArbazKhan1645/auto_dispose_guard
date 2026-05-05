import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:auto_dispose_guard/src/core/dispose_engine.dart';
import 'package:auto_dispose_guard/src/models/tracked_resource.dart';
import 'package:auto_dispose_guard/src/utils/logger.dart';

/// Tracks and manages a set of disposable resources for a single scope.
///
/// Key properties:
/// - **O(1)** registration, lookup, and removal (identity hash map)
/// - **LIFO** disposal order — last-registered resources are freed first,
///   which mirrors constructor/destructor semantics
/// - **Idempotent** — [disposeAll] is safe to call multiple times
/// - **Fail-safe** — individual disposal errors are caught, logged, and do
///   not interrupt the disposal of remaining resources
final class DisposeRegistry {
  DisposeRegistry({this.debugLabel = 'unnamed'});

  /// Label shown in debug output. Defaults to `'unnamed'`.
  final String debugLabel;

  // LinkedHashMap with identity equality gives O(1) ops and preserves
  // insertion order for LIFO disposal without an extra data structure.
  final LinkedHashMap<Object, TrackedResource> _resources = LinkedHashMap(
    equals: identical,
    hashCode: identityHashCode,
  );

  bool _disposed = false;

  /// Whether [disposeAll] has been called on this registry.
  bool get isDisposed => _disposed;

  /// Number of resources currently tracked (not yet disposed).
  int get resourceCount => _resources.length;

  // ─── Mutation ──────────────────────────────────────────────────────────────

  /// Registers [object] for auto-disposal when [disposeAll] is called.
  ///
  /// - **Idempotent**: registering the same object reference twice is a no-op.
  /// - [disposeCallback] overrides auto-detection — use for custom teardown.
  ///
  /// Asserts in debug mode if called after [disposeAll].
  void register(
    Object object, {
    void Function()? disposeCallback,
  }) {
    assert(
      !_disposed,
      'DisposeRegistry[$debugLabel]: register() called after disposeAll().\n'
      'Ensure you are not registering resources after the owning State has been disposed.',
    );

    if (_resources.containsKey(object)) return;

    final tracked = DisposeEngine.createTracked(
      object,
      disposeCallback: disposeCallback,
      registrationTrace: kDebugMode ? StackTrace.current : null,
    );

    if (tracked != null) {
      _resources[object] = tracked;
    }
  }

  /// Removes [object] from the registry **without** disposing it.
  ///
  /// Use when you want to take ownership of disposal back from the registry.
  void unregister(Object object) {
    _resources.remove(object);
  }

  // ─── Queries ───────────────────────────────────────────────────────────────

  /// Returns `true` if [object] is currently registered.
  bool isRegistered(Object object) => _resources.containsKey(object);

  // ─── Disposal ──────────────────────────────────────────────────────────────

  /// Disposes a single registered resource immediately and removes it.
  ///
  /// No-op if [object] is not registered or already disposed.
  void disposeResource(Object object) {
    final tracked = _resources.remove(object);
    if (tracked == null || tracked.isDisposed) return;
    _dispatchDispose(tracked);
  }

  /// Disposes all registered resources in **LIFO** order, then clears the registry.
  ///
  /// Subsequent calls are no-ops (safe re-entrancy).
  void disposeAll() {
    if (_disposed) return;
    _disposed = true;

    // Snapshot before clearing so that dispose callbacks cannot mutate
    // the registry mid-iteration.
    final snapshot = _resources.values.toList(growable: false);
    _resources.clear();

    for (var i = snapshot.length - 1; i >= 0; i--) {
      _dispatchDispose(snapshot[i]);
    }

    AutoDisposeLogger.summary(snapshot.length, debugLabel);
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  void _dispatchDispose(TrackedResource tracked) {
    if (tracked.isDisposed) return;
    try {
      tracked.dispose();
      AutoDisposeLogger.disposed(tracked.typeName);
    } catch (error, trace) {
      // Fail-safe: log and continue; one bad disposal must not block the rest.
      AutoDisposeLogger.error(tracked.typeName, error, trace);
    }
  }
}
