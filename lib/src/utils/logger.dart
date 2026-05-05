import 'package:flutter/foundation.dart';

/// Structured, zero-cost debug logger for AutoDisposeGuard.
///
/// Every method is a no-op in release builds (`kDebugMode == false`),
/// so there is strictly zero runtime overhead in production.
abstract final class AutoDisposeLogger {
  static void info(String scope, String message) {
    if (!kDebugMode) return;
    debugPrint('[AutoDisposeGuard] $scope → $message');
  }

  static void warn({
    required String resource,
    required String issue,
    required String action,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '\n⚠️  AutoDisposeGuard Warning:\n'
      '   Controller : $resource\n'
      '   Issue      : $issue\n'
      '   Action     : $action\n',
    );
  }

  static void error(String resource, Object error, StackTrace? trace) {
    if (!kDebugMode) return;
    debugPrint(
      '\n❌ AutoDisposeGuard Error:\n'
      '   Resource : $resource\n'
      '   Error    : $error\n'
      '   Trace    : ${trace ?? 'N/A'}\n',
    );
  }

  static void disposed(String resource) {
    if (!kDebugMode) return;
    debugPrint('✅ AutoDisposeGuard: Auto-disposed [$resource]');
  }

  static void summary(int count, String label) {
    if (!kDebugMode) return;
    debugPrint(
      '[AutoDisposeGuard] Scope "$label" released $count resource(s)',
    );
  }
}
