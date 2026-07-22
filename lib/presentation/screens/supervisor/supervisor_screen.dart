import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/agent_providers.dart';
import '../../providers/rbac_provider.dart';
import '../../providers/repository_providers.dart';
import '../../../data/datasources/api_clients.dart';

class SupervisorScreen extends ConsumerWidget {
  const SupervisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rbac = ref.watch(rbacProvider);
    if (!rbac.canUseSupervisorTools) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supervisor')),
        body: const Center(child: Text('Supervisor tools require supervisor role')),
      );
    }

    final board = ref.watch(supervisorBoardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(supervisorBoardProvider),
          ),
        ],
      ),
      body: board.when(
        data: (agents) {
          if (agents.isEmpty) {
            return const Center(child: Text('No agents online'));
          }
          return ListView.separated(
            itemCount: agents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = agents[i];
              final id = a['id']?.toString() ?? '';
              final name = a['name']?.toString() ?? id;
              final status = a['status']?.toString() ?? 'unknown';
              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                title: Text(name),
                subtitle: Text(status),
                trailing: PopupMenuButton<String>(
                  onSelected: (mode) async {
                    await SupervisorApi().monitor(agentId: id, mode: mode);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$mode started for $name')),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'listen', child: Text('Listen')),
                    PopupMenuItem(value: 'whisper', child: Text('Whisper')),
                    PopupMenuItem(value: 'barge', child: Text('Barge')),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Board unavailable\n$e')),
      ),
    );
  }
}

class QueuesScreen extends ConsumerWidget {
  const QueuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queues = ref.watch(queuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(queuesProvider),
          ),
        ],
      ),
      body: queues.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No queues configured'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final q = list[i];
              return ListTile(
                title: Text(q.name),
                subtitle: Text('Waiting: ${q.waiting} · Longest: ${q.longestWaitSec}s'),
                trailing: Switch(
                  value: q.loggedIn,
                  onChanged: (on) async {
                    final repo = ref.read(queueRepositoryProvider);
                    if (on) {
                      await repo.login(q.id);
                    } else {
                      await repo.logout(q.id);
                    }
                    ref.invalidate(queuesProvider);
                  },
                ),
                onLongPress: q.loggedIn
                    ? () async {
                        await ref.read(queueRepositoryProvider).setPaused(q.id, !q.paused);
                        ref.invalidate(queuesProvider);
                      }
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Queues unavailable\n$e')),
      ),
    );
  }
}
