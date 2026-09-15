import 'dart:convert';

import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../datasources/api_clients.dart';

/// Queues failed API writes for retry when connectivity returns.
class OfflineSyncQueue {
  OfflineSyncQueue._();
  static final instance = OfflineSyncQueue._();

  static const _key = 'offline_sync_queue';

  Future<void> clear() async {
    await StorageService.remove(_key);
  }

  Future<void> purgeIfNoBackend() async {
    if (!AppConfig.hasBackendConfigured) await clear();
  }

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    if (!AppConfig.enableOfflineSync || !AppConfig.hasBackendConfigured) return;
    final list = await _load();
    list.add({
      'type': type,
      'payload': payload,
      'at': DateTime.now().toIso8601String(),
    });
    await StorageService.setString(_key, jsonEncode(list));
  }

  Future<void> flush() async {
    if (!AppConfig.enableOfflineSync || !AppConfig.hasBackendConfigured) return;
    final list = await _load();
    if (list.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    final agentApi = AgentApi();
    final voiceApi = VoiceApi();

    for (final item in list) {
      final type = item['type']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      try {
        switch (type) {
          case 'agent_status':
            await agentApi.updateStatus(
              mode: payload['mode']?.toString() ?? 'online',
              reason: payload['reason']?.toString(),
              customReason: payload['customReason']?.toString(),
            );
            break;
          case 'wrap_up':
            await voiceApi.wrapUp(
              callId: payload['callId']?.toString() ?? '',
              disposition: null,
              note: payload['note']?.toString(),
              followUpAt: payload['followUpAt'] != null
                  ? DateTime.tryParse(payload['followUpAt'].toString())
                  : null,
            );
            break;
          case 'contact':
            await voiceApi.upsertContact(payload);
            break;
          default:
            remaining.add(item);
        }
      } catch (_) {
        remaining.add(item);
      }
    }
    await StorageService.setString(_key, jsonEncode(remaining));
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
