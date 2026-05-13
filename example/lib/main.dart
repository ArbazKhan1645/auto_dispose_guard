library;

import 'dart:async';

import 'package:auto_dispose_guard/auto_dispose_guard.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AutoDisposeExampleApp());

class AutoDisposeExampleApp extends StatelessWidget {
  const AutoDisposeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoDisposeGuard Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// ─── Home ─────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoDisposeGuard 1.0.3')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            icon: Icons.widgets_outlined,
            title: 'AutoDisposeMixin',
            subtitle: 'State-class mixin: controllers, animations, streams',
            onTap: () => _push(context, const FormScreen()),
          ),
          _DemoTile(
            icon: Icons.route_outlined,
            title: 'AutoDisposeScope',
            subtitle: 'Widget-tree scope — register from any descendant',
            onTap: () => _push(
              context,
              const AutoDisposeScope(
                debugLabel: 'ScopeScreen',
                child: ScopeScreen(),
              ),
            ),
          ),
          _DemoTile(
            icon: Icons.settings_suggest_outlined,
            title: 'AutoDisposeBagMixin (GetX / Provider)',
            subtitle: 'Controller/service bag outside widget State',
            onTap: () => _push(context, const ServiceScreen()),
          ),
          _DemoTile(
            icon: Icons.view_stream_outlined,
            title: 'BlocAutoDisposeMixin',
            subtitle: 'Bloc, Cubit, Riverpod StateNotifier',
            onTap: () => _push(context, const BlocScreen()),
          ),
          _DemoTile(
            icon: Icons.change_circle_outlined,
            title: 'AutoDisposeChangeNotifier',
            subtitle: 'Provider / Riverpod ChangeNotifier models',
            onTap: () => _push(context, const ChangeNotifierScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

// ─── 1. AutoDisposeMixin ──────────────────────────────────────────────────────

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen>
    with SingleTickerProviderStateMixin, AutoDisposeMixin {
  late final name = register(TextEditingController());
  late final email = register(TextEditingController());
  late final focus = register(FocusNode());
  late final animation = register(
    AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true),
  );
  late final counterStream = register(StreamController<int>.broadcast());
  late final subscription = register(
    counterStream.stream.listen((value) {
      if (mounted) setState(() => streamValue = value);
    }),
  );

  int streamValue = 0;

  @override
  void initState() {
    super.initState();
    // Lifecycle hook — fires after all resources are released.
    addDisposeListener(
      () => debugPrint('[Example] FormScreen fully cleaned up'),
    );
  }

  @override
  Widget build(BuildContext context) {
    subscription; // ensure late field is initialized
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoDisposeMixin'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, __) => LinearProgressIndicator(value: animation.value),
          ),
        ),
      ),
      body: _ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              focusNode: focus,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _CounterCard(
              label: 'StreamController counter',
              value: streamValue,
              onIncrement: () => counterStream.add(streamValue + 1),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // Dispose the animation early — safe, idempotent.
                if (isRegistered(animation)) {
                  disposeOf(animation);
                  setState(() {});
                }
              },
              child: Text(
                isRegistered(animation)
                    ? 'Dispose animation early'
                    : 'Animation disposed',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2. AutoDisposeScope ──────────────────────────────────────────────────────

class ScopeScreen extends StatefulWidget {
  const ScopeScreen({super.key});

  @override
  State<ScopeScreen> createState() => _ScopeScreenState();
}

class _ScopeScreenState extends State<ScopeScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController controller;
  late final AnimationController pulse;
  late final StreamController<String> logs;
  late final StreamSubscription<String> subscription;
  final items = <String>[];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController().autoDispose(context);
    pulse = (AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true))
        .autoDispose(context);
    logs = StreamController<String>.broadcast().autoDispose(context);
    subscription = logs.stream.listen((message) {
      if (mounted) setState(() => items.insert(0, message));
    }).autoDispose(context);
  }

  @override
  Widget build(BuildContext context) {
    subscription;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoDisposeScope'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => LinearProgressIndicator(value: pulse.value),
          ),
        ),
      ),
      body: _ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Type something',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => logs.add(DateTime.now().toIso8601String()),
              icon: const Icon(Icons.add),
              label: const Text('Add stream event'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. AutoDisposeBagMixin (GetX / Provider style) ──────────────────────────

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  late final service = DemoService();

  @override
  void dispose() {
    service.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = service.searchController;
    return Scaffold(
      appBar: AppBar(title: const Text('AutoDisposeBagMixin')),
      body: _ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Service-owned controller',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: service.closeSocketEarly,
              child: const Text('Close stream early'),
            ),
            const SizedBox(height: 12),
            Text(
              'Tracked resources: ${service.disposeRegistry.resourceCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class DemoService with AutoDisposeBagMixin {
  late final searchController = register(TextEditingController());
  late final StreamController<String> socket = register(
    StreamController<String>.broadcast(),
    isDisposed: () => socket.isClosed,
  );
  late final heartbeat =
      register(Timer.periodic(const Duration(seconds: 5), (_) {}));

  Future<void> closeSocketEarly() => socket.close();

  // In GetX: override onClose() and call disposeAutoDispose().
  // In Provider/ChangeNotifier: call disposeAutoDispose() before super.dispose().
  void onClose() => disposeAutoDispose();
}

// ─── 4. BlocAutoDisposeMixin ──────────────────────────────────────────────────

class BlocScreen extends StatefulWidget {
  const BlocScreen({super.key});

  @override
  State<BlocScreen> createState() => _BlocScreenState();
}

class _BlocScreenState extends State<BlocScreen> {
  // Simulates a Cubit/Bloc — no flutter_bloc dependency needed in this example.
  final cubit = CounterCubit();

  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocAutoDisposeMixin')),
      body: _ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Simulated Cubit',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    StreamBuilder<int>(
                      stream: cubit.stream,
                      initialData: cubit.state,
                      builder: (context, snap) => Text(
                        '${snap.data}',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: cubit.increment,
                      child: const Text('Increment'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Registered resources: ${cubit.resourceCount}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'When you pop this screen, close() is called on the Cubit.\n'
              'BlocAutoDisposeMixin disposes the internal Timer and '
              'StreamSubscription before close() finishes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulated Cubit — demonstrates BlocAutoDisposeMixin without a flutter_bloc
/// dependency in the example app.
class CounterCubit with BlocAutoDisposeMixin {
  CounterCubit() {
    // Auto-tick every second — disposed when close() is called.
    register(
      Timer.periodic(const Duration(seconds: 1), (_) => _emit(_state + 1)),
    );
    // Subscribe to our own stream — also auto-disposed.
    register(
      _controller.stream.listen((v) {
        _state = v;
        // In a real Bloc this would emit() a new state.
      }),
    );

    addDisposeListener(
      () => debugPrint('[Example] CounterCubit resources fully released'),
    );
  }

  int _state = 0;
  int get state => _state;

  final _controller = StreamController<int>.broadcast();
  Stream<int> get stream => _controller.stream;

  void increment() => _emit(_state + 1);

  void _emit(int value) {
    if (_controller.isClosed) return;
    _state = value;
    _controller.add(value);
  }

  /// Call from your real Bloc's close() override before super.close().
  void close() {
    disposeAutoDispose();
    _controller.close();
  }
}

// ─── 5. AutoDisposeChangeNotifier ─────────────────────────────────────────────

class ChangeNotifierScreen extends StatefulWidget {
  const ChangeNotifierScreen({super.key});

  @override
  State<ChangeNotifierScreen> createState() => _ChangeNotifierScreenState();
}

class _ChangeNotifierScreenState extends State<ChangeNotifierScreen> {
  final model = CounterModel();

  @override
  void initState() {
    super.initState();
    model.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoDisposeChangeNotifier')),
      body: _ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CounterCard(
              label: 'Auto-tick counter (Timer registered via register())',
              value: model.count,
              onIncrement: model.increment,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: model.search,
              decoration: const InputDecoration(
                labelText: 'Search (TextEditingController auto-disposed)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pop the screen — dispose() is called on the model automatically.\n'
              'AutoDisposeChangeNotifier releases the Timer and '
              'TextEditingController before ChangeNotifier.dispose() finishes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provider/Riverpod-style model — no manual dispose() override needed.
class CounterModel extends AutoDisposeChangeNotifier {
  CounterModel() {
    // Timer auto-disposed when this ChangeNotifier is disposed.
    register(
      Timer.periodic(const Duration(seconds: 2), (_) {
        _count++;
        notifyListeners();
      }),
    );
  }

  int _count = 0;
  int get count => _count;

  // TextEditingController auto-disposed — no override needed.
  late final search = register(TextEditingController());

  void increment() {
    _count++;
    notifyListeners();
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

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
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ScreenPadding extends StatelessWidget {
  const _ScreenPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: child);
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.label,
    required this.value,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text('$value', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onIncrement,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
