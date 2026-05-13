import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:auto_dispose_guard/src/models/tracked_resource.dart';
import 'package:auto_dispose_guard/src/utils/logger.dart';

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

/// Implement this when your custom resource can report its disposal state.
///
/// If [isDisposed] returns `true`, AutoDisposeGuard skips teardown to avoid
/// double-dispose crashes.
abstract interface class DisposeState {
  bool get isDisposed;
}

/// Stateless engine that resolves the correct disposal strategy for any object.
///
/// Detection priority:
/// 1. Explicit `disposeCallback` supplied by the caller
/// 2. [Disposable] marker interface -> `dispose()`
/// 3. [Closeable] marker interface -> `close()`
/// 4. [Cancellable] marker interface -> `cancel()`
/// 5. `ChangeNotifier` -> `dispose()`
/// 6. `StreamController` -> `close()`
/// 7. `StreamSubscription` -> `cancel()`
/// 8. `Timer` -> `cancel()`
///
/// Returns `null` and emits a debug warning when no strategy is found.
abstract final class DisposeEngine {
  /// Builds a [TrackedResource] for [object], or returns `null` when no
  /// disposal strategy could be detected.
  static TrackedResource? createTracked(
    Object object, {
    void Function()? disposeCallback,
    bool Function()? isDisposed,
    StackTrace? registrationTrace,
  }) {
    final typeName = object.runtimeType.toString();
    final fn = disposeCallback ?? _resolve(object);
    final disposedProbe = isDisposed ?? _resolveDisposedProbe(object);

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
      isDisposed: disposedProbe,
      registrationTrace: registrationTrace,
    );
  }

  static void Function()? _resolve(Object object) {
    if (object is Disposable) return object.dispose;
    if (object is Closeable) return object.close;
    if (object is Cancellable) return object.cancel;

    if (object is ChangeNotifier) return object.dispose;

    if (object is StreamController) return () => object.close();
    if (object is StreamSubscription) return () => object.cancel();
    if (object is Timer) return object.cancel;

    return null;
  }

  static bool Function()? _resolveDisposedProbe(Object object) {
    if (object is DisposeState) return () => object.isDisposed;
    if (object is StreamController) return () => object.isClosed;
    if (object is Timer) return () => !object.isActive;
    return null;
  }
}
