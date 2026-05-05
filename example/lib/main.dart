/// AutoDisposeGuard — full example app.
///
/// Demonstrates all three registration APIs:
///   1. AutoDisposeMixin  (FormScreen)
///   2. AutoDisposeScope  (ScopeScreen)
///   3. .autoDispose()    (inline extension, also in ScopeScreen)
///
/// Run with `flutter run` and watch the debug console when navigating away.
library;

import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AutoDisposeExampleApp());

// ─────────────────────────────────────────────────────────────────────────────
// App root
// ─────────────────────────────────────────────────────────────────────────────

class AutoDisposeExampleApp extends StatelessWidget {
  const AutoDisposeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoDisposeGuard Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoDisposeGuard')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DemoTile(
              icon: Icons.tune,
              title: 'AutoDisposeMixin',
              subtitle: 'State mixin — zero dispose() boilerplate',
              onTap: () => _push(context, const FormScreen()),
            ),
            const SizedBox(height: 12),
            _DemoTile(
              icon: Icons.view_in_ar,
              title: 'AutoDisposeScope',
              subtitle: 'InheritedWidget scope + .autoDispose() extension',
              onTap: () => _push(
                context,
                const AutoDisposeScope(
                  debugLabel: 'ScopeScreen',
                  child: ScopeScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext ctx, Widget screen) {
    Navigator.push<void>(ctx, MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method 1: AutoDisposeMixin
// ─────────────────────────────────────────────────────────────────────────────

/// Demonstrates [AutoDisposeMixin].
///
/// Notice: no `@override void dispose()` anywhere in this class.
/// All controllers are declared as `late final` fields using `register()`.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  // ── Registered resources ── all auto-disposed when the route is popped ──

  late final _nameController = register(TextEditingController());
  late final _emailController = register(TextEditingController());
  late final _focusNode = register(FocusNode());

  // AnimationController requires vsync — initialize in the field directly.
  late final _animation = register(
    AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true),
  );

  late final _counterStream = register(StreamController<int>.broadcast());

  // StreamSubscription auto-detected via `is StreamSubscription`.
  // Not stored — register() handles lifetime; the value is not needed elsewhere.
  // ignore: unused_field
  late final _sub = register(
    _counterStream.stream.listen(
      (v) => setState(() => _streamValue = v),
    ),
  );

  int _streamValue = 0;

  void _increment() => _counterStream.add(_streamValue + 1);

  // ── No dispose() override ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoDisposeMixin Demo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => LinearProgressIndicator(
              value: _animation.value,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel(
              '6 resources registered — pop this screen to auto-dispose all',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            _CounterCard(
              value: _streamValue,
              onIncrement: _increment,
              label: 'StreamController counter',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method 2: AutoDisposeScope + .autoDispose() extension
// ─────────────────────────────────────────────────────────────────────────────

/// Demonstrates [AutoDisposeScope] and the `.autoDispose(context)` extension.
///
/// The [AutoDisposeScope] wrapper is added in [HomeScreen._push], not here,
/// so this screen is a plain [StatefulWidget] — no mixin needed.
class ScopeScreen extends StatefulWidget {
  const ScopeScreen({super.key});

  @override
  State<ScopeScreen> createState() => _ScopeScreenState();
}

class _ScopeScreenState extends State<ScopeScreen>
    with SingleTickerProviderStateMixin {
  // Resources are registered via the inherited scope using the extension.
  // initState is the right place because getInheritedWidgetOfExactType
  // (used internally) is safe to call from initState.
  late final TextEditingController _nameController;
  late final AnimationController _pulseAnimation;
  late final StreamController<String> _logStream;
  // ignore: unused_field
  late final StreamSubscription<String> _logSub;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();

    // Extension API — inline, type-safe, fluent.
    _nameController = TextEditingController().autoDispose(context);

    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..repeat(reverse: true)
      ..autoDispose(context);

    _logStream = StreamController<String>.broadcast()..autoDispose(context);

    _logSub = _logStream.stream.listen((msg) {
      setState(() => _logs.insert(0, msg));
    })..autoDispose(context);

    // Alternatively use AutoDispose.of(context) for imperative registration:
    // AutoDispose.of(context).register(_nameController);
  }

  void _addLog() {
    _logStream.add('Event at ${DateTime.now().toIso8601String()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoDisposeScope Demo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => LinearProgressIndicator(
              value: _pulseAnimation.value,
              backgroundColor: Colors.transparent,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel(
              '4 resources via .autoDispose(context) — pop to auto-dispose',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Type something',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addLog,
              icon: const Icon(Icons.add),
              label: const Text('Add stream event'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(_logs[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom type example — implement Disposable for zero-config support
// ─────────────────────────────────────────────────────────────────────────────

/// A mock service that holds an expensive resource.
class AnalyticsService implements Disposable {
  AnalyticsService() {
    debugPrint('[AnalyticsService] initialized');
  }

  @override
  void dispose() {
    debugPrint('[AnalyticsService] disposed');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.value,
    required this.onIncrement,
    required this.label,
  });

  final int value;
  final VoidCallback onIncrement;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onIncrement,
              child: const Text('Increment via Stream'),
            ),
          ],
        ),
      ),
    );
  }
}
