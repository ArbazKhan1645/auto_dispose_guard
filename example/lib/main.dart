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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AutoDisposeGuard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            icon: Icons.widgets_outlined,
            title: 'State mixin',
            subtitle: 'Controllers, focus nodes, animations, and streams',
            onTap: () => _push(context, const FormScreen()),
          ),
          _DemoTile(
            icon: Icons.route_outlined,
            title: 'Widget scope',
            subtitle: 'Register resources from any descendant',
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
            title: 'Controller/service bag',
            subtitle: 'GetX, Provider, blocs, services, and repositories',
            onTap: () => _push(context, const ServiceScreen()),
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
  Widget build(BuildContext context) {
    subscription;
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
          ],
        ),
      ),
    );
  }
}

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
                'Registered resources: ${service.disposeRegistry.resourceCount}'),
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

  // In GetX, put this body inside `onClose()`.
  // In Provider/ChangeNotifier, call `disposeAutoDispose()` before `super.dispose()`.
  void onClose() => disposeAutoDispose();
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
