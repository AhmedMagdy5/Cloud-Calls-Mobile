import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../data/call_history_store.dart';
import '../../data/follow_up_state_store.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/agent_assist_entity.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/queue_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/call_entity.dart';
import 'repository_providers.dart';

final customerLookupProvider =
    FutureProvider.family<CustomerEntity?, String>((ref, phone) async {
  if (phone.isEmpty) return null;
  return ref.read(customerRepositoryProvider).lookupByPhone(phone);
});

final pendingTasksProvider = FutureProvider<List<TaskEntity>>((ref) async {
  if (!AppConfig.hasBackendConfigured) return [];
  try {
    return await ref
        .read(taskRepositoryProvider)
        .fetchPending()
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    return [];
  }
});

TaskEntity _followUpToTask(CallEntity call, {DateTime? calledAtOverride}) => TaskEntity(
      id: 'local:${call.id}',
      title: 'Follow-up: ${call.displayName?.isNotEmpty == true ? call.displayName : call.number}',
      number: call.number,
      callId: call.id,
      dueAt: call.followUpAt,
      followUpCalledAt: calledAtOverride ?? call.followUpCalledAt,
      followUpCompletedAt: call.followUpCompletedAt,
      actionNote: call.followUpActionNote,
      createdAt: call.endedAt ?? call.startedAt,
    );

class FollowUpTaskLists {
  final List<TaskEntity> pending;
  final List<TaskEntity> done;
  const FollowUpTaskLists({required this.pending, required this.done});
}

/// Backend tasks + local follow-ups split into pending and done lists.
final tasksAndFollowUpsProvider = FutureProvider<FollowUpTaskLists>((ref) async {
  ref.keepAlive();
  await CallHistoryStore.instance.load();

  final remote = AppConfig.hasBackendConfigured
      ? await ref.read(pendingTasksProvider.future)
      : const <TaskEntity>[];

  final calledMap = FollowUpStateStore.instance.calledAtByPhone();

  final pendingLocal = CallHistoryStore.instance
      .activeFollowUps()
      .map(_followUpToTask)
      .toList();

  final doneLocal = CallHistoryStore.instance.handledFollowUps().map((call) {
    final calledAt = call.followUpCalledAt ??
        (call.number.isNotEmpty
            ? calledMap[FollowUpStateStore.normalizePhone(call.number)]
            : null);
    return _followUpToTask(call, calledAtOverride: calledAt);
  }).toList();

  final remoteCallIds =
      remote.map((t) => t.callId).whereType<String>().where((id) => id.isNotEmpty).toSet();

  final pending = [
    ...pendingLocal.where((t) => t.callId == null || !remoteCallIds.contains(t.callId)),
    ...remote,
  ]..sort((a, b) {
      final ad = a.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });

  return FollowUpTaskLists(pending: pending, done: doneLocal);
});

final queuesProvider = FutureProvider<List<QueueEntity>>((ref) async {
  try {
    return await ref.read(queueRepositoryProvider).fetchQueues();
  } catch (_) {
    return [];
  }
});

final chatMessagesProvider = FutureProvider<List<ChatMessageEntity>>((ref) async {
  try {
    return await ref.read(chatApiProvider).messages();
  } catch (_) {
    return [];
  }
});

final callAssistSummaryProvider =
    FutureProvider.family<AgentAssistSummary?, String>((ref, callId) async {
  if (callId.isEmpty) return null;
  return ref.read(agentAssistApiProvider).summarizeCall(callId);
});

final knowledgeSearchProvider =
    FutureProvider.family<List<String>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.read(agentAssistApiProvider).searchKnowledge(query.trim());
});

final supervisorBoardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(supervisorApiProvider).agentBoard();
  } catch (_) {
    return [];
  }
});

final voicemailProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.read(voiceApiProvider).voicemail();
  } catch (_) {
    return [];
  }
});
