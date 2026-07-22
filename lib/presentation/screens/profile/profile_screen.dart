import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: CircleAvatar(radius: 50, backgroundColor: cs.primary.withOpacity(0.15), child: Icon(Icons.person, size: 60, color: cs.primary))),
        const SizedBox(height: 16),
        Center(child: Text(user?.name ?? 'Guest', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        Center(child: Text(user?.email ?? '—', style: TextStyle(color: cs.onSurface.withOpacity(0.6)))),
        const SizedBox(height: 24),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Extension'), trailing: Text(user?.extension ?? '—')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.business_outlined), title: const Text('Department'), trailing: Text(user?.department ?? '—')),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.work_outline), title: const Text('Role'), trailing: Text(user?.role ?? '—')),
        ])),
      ]),
    );
  }
}
