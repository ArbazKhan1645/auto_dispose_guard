import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:auto_dispose_guard/src/models/tracked_resource.dart';
import 'package:auto_dispose_guard/src/utils/logger.dart';

// ─── Marker interfaces ────────────────────────────────────────────────────────

/// Implement this on any class that should be auto-detected for disposal.
///
/// ```dart
/// class MyBloc implements Disposable {
///   @override
///   void dispose() { /* cleanup */ }
/// }
/// ```
abstract interface class Disposable {
  void dispose();
}

/// Implement this on any class with a `close()` teardown method.
abstract interface class Closeable {
  void close();
}

/// Implement this on any class with a `cancel()` teardown method.
abstract interface class Cancellable {
  void cancel();
}

// ─── Engine ───────────────────────────────────────────────────────────────────

/// Stateless engine that resolves the correct disposal strategy for any object.
///
/// **Detection priority** (first match wins):
///
/// 1. Explicit `disposeCallback` supplied by the caller
/// 2. [Disposable] marker interface → `dispose()`
/// 3. [Closeable] marker interface  → `close()`
/// 4. [Cancellable] marker interface → `cancel()`
/// 5. `ChangeNotifier` (covers all Flutter built-in controllers) → `dispose()`
/// 6. `StreamController` → `close()` (Future discarded safely)
/// 7. `StreamSubscription` → `cancel()` (Future discarded safely)
/// 8. `Timer` → `cancel()`
///
/// Returns `null` — and emits a debug warning — when no strategy is found.
abstract final class DisposeEngine {
  /// Builds a [TrackedResource] for [object], or returns `null` when no
  /// disposal strategy could be detected.
  static TrackedResource? createTracked(
    Object object, {
    void Function()? disposeCallback,
    StackTrace? registrationTrace,
  }) {
    final typeName = object.runtimeType.toString();
    final fn = disposeCallback ?? _resolve(object);

    if (fn == null) {
      AutoDisposeLogger.warn(
        resource: typeName,
        issue: 'No disposal method detected (dispose / close / cancel)',
        action: 'Object skipped. Implement Disposable, Closeable, Cancellable, '
            'or pass a disposeCallback.',
      );
      return null;
    }

    return TrackedResource(
      resource: object,
      typeName: typeName,
      disposeFn: fn,
      registrationTrace: registrationTrace,
    );
  }

  static void Function()? _resolve(Object object) {
    // User-defined marker interfaces take highest priority.
    if (object is Disposable) return object.dispose;
    if (object is Closeable) return object.close;
    if (object is Cancellable) return object.cancel;

    // Flutter framework types — ordered by real-world usage frequency.
    // ChangeNotifier.dispose() covers TextEditingController, AnimationController,
    // ScrollController, FocusNode, PageController, TabController, and more.
    if (object is ChangeNotifier) return object.dispose;

    // StreamController.close() and StreamSubscription.cancel() return
    // Future<void>; we intentionally discard the Future — disposal does not
    // need to be awaited in a widget lifecycle context.
    if (object is StreamController) return () => object.close();
    if (object is StreamSubscription) return () => object.cancel();

    // Timer.cancel() is void — no wrapping needed.
    if (object is Timer) return object.cancel;

    return null;
  }
}
