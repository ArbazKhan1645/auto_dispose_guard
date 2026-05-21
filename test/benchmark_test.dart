import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BenchDisposable implements Disposable {
  @override
  void dispose() {}
}

void main() {
  group('Benchmark Tests', () {
    test('registration performance — 10,000 ops under 2 seconds', () {
      final registry = DisposeRegistry(debugLabel: 'bench-reg');
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10000; i++) {
        registry.register(_BenchDisposable());
      }

      stopwatch.stop();
      final perOp = stopwatch.elapsedMicroseconds / 10000;

      // ignore: avoid_print
      print('Registration: ${perOp.toStringAsFixed(2)}μs/op '
          '(${stopwatch.elapsedMilliseconds}ms total)');

      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: '10K registrations should complete under 2s');

      registry.disposeAll();
    });

    test('disposal performance — 10,000 ops under 2 seconds', () {
      final registry = DisposeRegistry(debugLabel: 'bench-dispose');
      for (var i = 0; i < 10000; i++) {
        registry.register(_BenchDisposable());
      }

      final stopwatch = Stopwatch()..start();
      registry.disposeAll();
      stopwatch.stop();

      final perOp = stopwatch.elapsedMicroseconds / 10000;

      // ignore: avoid_print
      print('Disposal: ${perOp.toStringAsFixed(2)}μs/op '
          '(${stopwatch.elapsedMilliseconds}ms total)');

      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: '10K disposals should complete under 2s');
    });

    test('identity check cost with 10,000 existing entries', () {
      final registry = DisposeRegistry(debugLabel: 'bench-identity');

      // Pre-fill with 10K entries
      final existing = List.generate(10000, (_) => _BenchDisposable());
      for (final obj in existing) {
        registry.register(obj);
      }

      // Now register a new object — should be fast due to identity hash map
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        registry.register(_BenchDisposable());
      }
      stopwatch.stop();

      final perOp = stopwatch.elapsedMicroseconds / 1000;

      // ignore: avoid_print
      print('Identity check with 10K entries: ${perOp.toStringAsFixed(2)}μs/op '
          '(${stopwatch.elapsedMilliseconds}ms total)');

      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Identity checks with 10K entries should be fast');

      registry.disposeAll();
    });

    test('duplicate registration performance — 10,000 duplicates', () {
      final registry = DisposeRegistry(debugLabel: 'bench-dup');
      final obj = _BenchDisposable();
      registry.register(obj);

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        registry.register(obj); // Should be no-op each time
      }
      stopwatch.stop();

      final perOp = stopwatch.elapsedMicroseconds / 10000;

      // ignore: avoid_print
      print('Duplicate registration: ${perOp.toStringAsFixed(2)}μs/op '
          '(${stopwatch.elapsedMilliseconds}ms total)');

      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Duplicate checks should be very fast (O(1))');

      registry.disposeAll();
    });

    test('TextEditingController mass creation + disposal benchmark', () {
      final registry = DisposeRegistry(debugLabel: 'bench-controllers');
      final stopwatch = Stopwatch()..start();

      final controllers = List.generate(1000, (_) => TextEditingController());
      for (final c in controllers) {
        registry.register(c);
      }

      final regTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();
      stopwatch.start();

      registry.disposeAll();
      stopwatch.stop();

      // ignore: avoid_print
      print('1K TextEditingControllers — register: ${regTime}ms, '
          'dispose: ${stopwatch.elapsedMilliseconds}ms');

      expect(regTime, lessThan(2000));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('AutoDisposeBag lifecycle benchmark', () {
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 1000; i++) {
        final bag = AutoDisposeBag(debugLabel: 'bench-$i');
        for (var j = 0; j < 10; j++) {
          bag.register(_BenchDisposable());
        }
        bag.dispose();
      }

      stopwatch.stop();

      // ignore: avoid_print
      print('1K bag lifecycles (10 resources each): '
          '${stopwatch.elapsedMilliseconds}ms');

      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: '1K bag lifecycles should complete under 3s');
    });
  });
}
