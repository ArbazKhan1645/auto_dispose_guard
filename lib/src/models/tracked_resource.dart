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
  /// Sets [isDisposed] to `true` *before* calling the function so that
  /// re-entrant calls during disposal are safe no-ops.
  void dispose() {
    if (_disposed) return;
    if (_isAlreadyDisposed()) {
      _disposed = true;
      return;
    }
    _disposed = true;
    _disposeFn();
  }

  bool _isAlreadyDisposed() {
    try {
      return _isDisposed?.call() ?? false;
    } catch (_) {
      return false;
    }
  }
}
