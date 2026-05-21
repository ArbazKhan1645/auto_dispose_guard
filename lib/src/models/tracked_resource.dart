/// Represents a single resource being managed by [DisposeRegistry].
///
/// Holds the disposal function, runtime metadata, and disposed state.
/// The disposal function is invoked exactly once — idempotent by design.
final class TrackedResource {
  TrackedResource({
    required this.resource,
    required this.typeName,
    required void Function() disposeFn,
    bool Function()? isDisposed,
    this.registrationTrace,
  })  : _disposeFn = disposeFn,
        _isDisposed = isDisposed,
        registeredAt = DateTime.now();

  /// The tracked object itself (held weakly via identity in [DisposeRegistry]).
  final Object resource;

  /// Cached runtime type name — survives post-disposal for logging.
  final String typeName;

  /// Wall-clock time of registration.
  final DateTime registeredAt;

  /// Call-site stack trace, populated only in debug mode.
  final StackTrace? registrationTrace;

  final void Function() _disposeFn;
  final bool Function()? _isDisposed;
  bool _disposed = false;

  /// Whether this resource has already been disposed.
  bool get isDisposed => _disposed || _isAlreadyDisposed();

  /// Executes the disposal function exactly once.
  ///
  /// Uses try/catch so that a failed disposal can be retried — [_disposed] is
  /// only set to `true` after a successful invocation. If the disposal function
  /// throws, the error propagates and the resource remains in a non-disposed
  /// state, allowing the caller to attempt disposal again.
  void dispose() {
    if (_disposed) return;
    if (_isAlreadyDisposed()) {
      _disposed = true;
      return;
    }
    try {
      _disposeFn();
      _disposed = true;
    } catch (_) {
      // Leave _disposed as false so the caller can retry.
      rethrow;
    }
  }

  bool _isAlreadyDisposed() {
    try {
      return _isDisposed?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  String toString() =>
      'TrackedResource($typeName, disposed: $_disposed, age: ${DateTime.now().difference(registeredAt).inMilliseconds}ms)';
}
