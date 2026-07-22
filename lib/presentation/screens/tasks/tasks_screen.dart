import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/services/follow_up_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/follow_up_state_store.dart';
import '../../../data/call_history_store.dart';
import '../../../domain/entities/task_entity.dart';
import '../../providers/agent_providers.dart';
import '../../providers/call_provider.dart';
import '../../providers/repository_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _history = CallHistoryStore.instance;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _history.load();
    _history.addListener(_onHistoryChange);
  }

  @override
  void dispose() {
    _tabs.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _history.removeListener(_onHistoryChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _onHistoryChange() {
    if (mounted) ref.invalidate(tasksAndFollowUpsProvider);
  }

  Future<void> _refresh() async {
    await _history.load();
    await FollowUpNotificationService.instance.syncFromHistory();
    ref.invalidate(pendingTasksProvider);
    ref.invalidate(tasksAndFollowUpsProvider);
  }

  Future<void> _dial(TaskEntity t) async {
    final number = t.number;
    if (number == null || number.isEmpty) return;
    try {
      final followUpCallId = await CallHistoryStore.instance.markFollowUpCalledForNumber(
        number,
        callId: t.callId,
      );
      if (followUpCallId != null && followUpCallId.isNotEmpty) {
        await FollowUpNotificationService.instance.cancelForCall(followUpCallId);
      }
      ref.invalidate(tasksAndFollowUpsProvider);

      await ref.read(callProvider).dial(number);
      if (mounted) {
        _tabs.animateTo(1);
        context.push('/call/active');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<String?> _promptActionNote(TaskEntity t) async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close follow-up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What action did you take with ${t.number ?? t.title}?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Customer confirmed order, will not call again…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save & close'),
          ),
        ],
      ),
    );
  }

  Future<void> _complete(TaskEntity t) async {
    final note = await _promptActionNote(t);
    if (!mounted || note == null) return;

    var closedLocally = false;
    if (t.isLocal && t.callId != null && t.callId!.isNotEmpty) {
      await CallHistoryStore.instance.completeFollowUp(
        t.callId!,
        actionNote: note.isEmpty ? null : note,
        number: t.number,
      );
      await FollowUpNotificationService.instance.cancelForCall(t.callId!);
      closedLocally = true;
    } else if (t.number != null && t.number!.isNotEmpty) {
      final target = FollowUpStateStore.normalizePhone(t.number!);
      for (final c in CallHistoryStore.instance.handledFollowUps()) {
        if (c.followUpCompletedAt != null) continue;
        if (FollowUpStateStore.normalizePhone(c.number) == target) {
          await CallHistoryStore.instance.completeFollowUp(
            c.id,
            actionNote: note.isEmpty ? null : note,
            number: t.number,
          );
          await FollowUpNotificationService.instance.cancelForCall(c.id);
          closedLocally = true;
          break;
        }
      }
      if (!closedLocally) {
        for (final c in CallHistoryStore.instance.activeFollowUps()) {
          if (FollowUpStateStore.normalizePhone(c.number) == target) {
            await CallHistoryStore.instance.completeFollowUp(
              c.id,
              actionNote: note.isEmpty ? null : note,
              number: t.number,
            );
            await FollowUpNotificationService.instance.cancelForCall(c.id);
            closedLocally = true;
            break;
          }
        }
      }
    }
    if (!closedLocally && !t.isLocal) {
      await ref.read(taskRepositoryProvider).complete(t.id);
    }
    ref.invalidate(pendingTasksProvider);
    ref.invalidate(tasksAndFollowUpsProvider);
  }

  Color _numberColor(TaskEntity t, ColorScheme cs, {required bool doneTab}) {
    if (t.isCompleted) return cs.onSurfaceVariant;
    if (doneTab || t.isCalled) return AppTheme.brandSuccess;
    if (t.isOverdue) return Colors.redAccent;
    if (t.isDueSoon) return Colors.amber.shade700;
    return cs.primary;
  }

  String _statusLabel(TaskEntity t, {required bool doneTab}) {
    if (t.isCompleted && t.followUpCompletedAt != null) {
      return 'Closed · ${DateFormat('MMM d, HH:mm').format(t.followUpCompletedAt!)}';
    }
    if (t.isCalled && t.followUpCalledAt != null) {
      return 'Called · ${DateFormat('MMM d, HH:mm').format(t.followUpCalledAt!)}';
    }
    if (t.isOverdue) return 'Overdue — call now';
    if (t.isDueSoon) {
      return 'Due in ${AppConfig.followUpReminderMinutes} min — call now';
    }
    return 'Scheduled';
  }

  IconData _leadingIcon(TaskEntity t) {
    if (t.isCompleted) return Icons.check_circle;
    if (t.isCalled) return Icons.call_made;
    if (t.isOverdue) return Icons.notification_important;
    if (t.isDueSoon) return Icons.alarm;
    return Icons.task_alt;
  }

  Widget _buildList(
    List<TaskEntity> list, {
    required bool doneTab,
    required ColorScheme cs,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          doneTab ? 'No handled follow-ups yet' : 'No pending follow-ups',
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = list[i];
        final numberColor = _numberColor(t, cs, doneTab: doneTab);
        final highlight = doneTab
            ? !t.isCompleted
            : (t.isOverdue || t.isDueSoon);

        return ListTile(
          tileColor: highlight ? numberColor.withOpacity(0.1) : null,
          leading: Icon(
            _leadingIcon(t),
            color: t.isCompleted ? AppTheme.brandSuccess : numberColor,
          ),
          title: Text(t.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.number != null && t.number!.isNotEmpty)
                Text(
                  t.number!,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: numberColor,
                  ),
                ),
              Text([
                _statusLabel(t, doneTab: doneTab),
                if (t.dueAt != null && !t.isCompleted)
                  doneTab
                      ? 'Was due ${DateFormat('MMM d, HH:mm').format(t.dueAt!)}'
                      : 'Due ${DateFormat('MMM d, HH:mm').format(t.dueAt!)}',
              ].join(' · ')),
              if (t.actionNote != null && t.actionNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    t.actionNote!,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          isThreeLine: true,
          trailing: t.isCompleted
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.number != null && t.number!.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.call, color: numberColor),
                        tooltip: 'Call',
                        onPressed: () => _dial(t),
                      ),
                    IconButton(
                      icon: Icon(Icons.check, color: AppTheme.brandSuccess),
                      tooltip: 'Done',
                      onPressed: () => _complete(t),
                    ),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksAndFollowUpsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Follow-ups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: tasks.maybeWhen(
                data: (lists) => Text('Pending (${lists.pending.length})'),
                orElse: () => const Text('Pending'),
              ),
            ),
            Tab(
              child: tasks.maybeWhen(
                data: (lists) => Text('Done (${lists.done.length})'),
                orElse: () => const Text('Done'),
              ),
            ),
          ],
        ),
      ),
      body: tasks.when(
        data: (lists) => TabBarView(
          controller: _tabs,
          children: [
            _buildList(lists.pending, doneTab: false, cs: cs),
            _buildList(lists.done, doneTab: true, cs: cs),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load tasks\n$e')),
      ),
    );
  }
}
