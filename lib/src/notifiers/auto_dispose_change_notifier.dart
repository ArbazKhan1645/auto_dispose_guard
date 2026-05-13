import 'package:flutter/foundation.dart';

import 'package:auto_dispose_guard/src/core/auto_dispose_bag.dart';

/// A [ChangeNotifier] that automatically disposes all registered resources
/// when [dispose] is called.
///
/// Extend this class instead of plain [ChangeNotifier] to get zero-boilerplate
/// resource management in Provider and Riverpod [StateNotifier] patterns.
///
/// ```dart
/// class CartModel extends AutoDisposeChangeNotifier {
///   late final search  = register(TextEditingController());
///   late final scroll  = register(ScrollController());
///   late final _timer  = register(
///     Timer.periodic(const Duration(seconds: 30), (_) => _sync()),
///   );
///
///   // No dispose() override needed — all resources are released automatically.
/// }
/// ```
///
/// ## With Provider
///
/// ```dart
/// ChangeNotifierProvider(create: (_) => CartModel())
/// ```
///
/// ## With Riverpod (StateNotifier style)
///
/// ```dart
/// class CartNotifier extends AutoDisposeChangeNotifier {
///   // StateNotifier<T> users: extend AutoDisposeChangeNotifier or use
///   // AutoDisposeBagMixin directly and call disposeAutoDispose() from dispose().
/// }
/// ```
///
/// If you need to run additional teardown logic, override [dispose] and call
/// `super.dispose()` **after** your cleanup so that notifier listeners are still
/// live while you wrap up:
///
/// ```dart
/// @override
/// void dispose() {
///   _socket.close();     // custom teardown
///   super.dispose();     // triggers disposeAutoDispose() + ChangeNotifier.dispose()
/// }
/// ```
abstract class AutoDisposeChangeNotifier extends ChangeNotifier
    with AutoDisposeBagMixin {
  @override
  void dispose() {
    disposeAutoDispose();
    super.dispose();
  }
}
