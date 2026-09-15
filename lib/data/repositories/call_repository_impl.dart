import '../../core/constants/app_config.dart';
import '../../data/call_history_store.dart';
import '../../data/datasources/api_clients.dart';
import '../../data/sync/offline_sync_queue.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';

class CallRepositoryImpl implements CallRepository {
  final VoiceApi _api;
  CallRepositoryImpl([VoiceApi? api]) : _api = api ?? VoiceApi();

  @override
  Future<List<CallEntity>> fetchRemoteHistory({int limit = 50}) async {
    if (!AppConfig.hasBackendConfigured) {
      await CallHistoryStore.instance.load();
      return CallHistoryStore.instance.items;
    }
    try {
      final items = await _api.history(limit: limit);
      final remote = items.map(_mapRemoteCall).toList();
      for (final c in remote) {
        await CallHistoryStore.instance.upsert(c);
      }
      return remote;
    } catch (_) {
      return CallHistoryStore.instance.items;
    }
  }

  @override
  Future<void> syncWrapUp({
    required String callId,
    CallDisposition? disposition,
    String? note,
    DateTime? followUpAt,
  }) async {
    if (!AppConfig.hasBackendConfigured) return;
    try {
      await _api.wrapUp(
        callId: callId,
        disposition: disposition,
        note: note,
        followUpAt: followUpAt,
      );
    } catch (e) {
      await OfflineSyncQueue.instance.enqueue(
        type: 'wrap_up',
        payload: {
          'callId': callId,
          if (disposition != null) 'disposition': disposition.name,
          if (note != null) 'note': note,
          if (followUpAt != null) 'followUpAt': followUpAt.toIso8601String(),
        },
      );
    }
  }

  CallEntity _mapRemoteCall(Map<String, dynamic> j) {
    final dir = j['direction']?.toString() == 'incoming'
        ? CallDirection.incoming
        : CallDirection.outgoing;
    final status = CallStatus.values.firstWhere(
      (e) => e.name == j['status']?.toString(),
      orElse: () => CallStatus.ended,
    );
    CallDisposition disp = CallDisposition.none;
    final dRaw = j['disposition']?.toString();
    if (dRaw != null) {
      disp = CallDisposition.values.firstWhere(
        (e) => e.name == dRaw,
        orElse: () => CallDisposition.none,
      );
    }
    return CallEntity(
      id: j['id']?.toString() ?? '',
      number: j['number']?.toString() ?? '',
      displayName: j['displayName']?.toString(),
      direction: dir,
      status: status,
      startedAt: DateTime.tryParse(j['startedAt']?.toString() ?? '') ?? DateTime.now(),
      answeredAt: j['answeredAt'] != null
          ? DateTime.tryParse(j['answeredAt'].toString())
          : null,
      endedAt: j['endedAt'] != null ? DateTime.tryParse(j['endedAt'].toString()) : null,
      note: j['note']?.toString(),
      disposition: disp,
      followUpAt: j['followUpAt'] != null
          ? DateTime.tryParse(j['followUpAt'].toString())
          : null,
    );
  }
}
