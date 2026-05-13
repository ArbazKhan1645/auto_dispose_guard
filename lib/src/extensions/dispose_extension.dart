import 'package:flutter/widgets.dart';

import 'package:auto_dispose_guard/src/widgets/auto_dispose_scope.dart';

/// Adds `.autoDispose(context)` to any [Object].
///
/// Designed for fluent, inline initialization at the call-site:
///
/// ```dart
/// // In initState or didChangeDependencies:
/// _name   = TextEditingController().autoDispose(context);
/// _stream = StreamController<int>().autoDispose(context);
/// _focus  = FocusNode().autoDispose(context);
///
/// // With a custom teardown:
/// _myThing = MyThing().autoDispose(context, onDispose: () => _myThing.teardown());
/// ```
///
/// Requires an [AutoDisposeScope] ancestor in the widget tree.
extension AutoDisposeExtension<T extends Object> on T {
  /// Registers `this` with the nearest [AutoDisposeScope] and returns `this`.
  ///
  /// - Return type is `T` — the calling code retains full static type
  ///   information with no casts.
  /// - [onDispose] overrides the auto-detected teardown method.
  /// - [isDisposed] skips teardown when the resource was already disposed.
  T autoDispose(
    BuildContext context, {
    void Function()? onDispose,
    bool Function()? isDisposed,
  }) {
    AutoDisposeScope.of(context).register(
      this,
      disposeCallback: onDispose,
      isDisposed: isDisposed,
    );
    return this;
  }
}
