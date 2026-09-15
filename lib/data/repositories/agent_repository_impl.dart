import '../../core/constants/app_config.dart';
import '../../data/datasources/api_clients.dart';
import '../../data/sync/offline_sync_queue.dart';
import '../../domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  final AgentApi _api;
  AgentRepositoryImpl([AgentApi? api]) : _api = api ?? AgentApi();

  @override
  Future<void> syncPresence({
    required String mode,
    String? reason,
    String? customReason,
  }) async {
    if (!AppConfig.hasBackendConfigured) return;
    try {
      await _api.updateStatus(
        mode: mode,
        reason: reason,
        customReason: customReason,
      );
    } catch (e) {
      await OfflineSyncQueue.instance.enqueue(
        type: 'agent_status',
        payload: {
          'mode': mode,
          if (reason != null) 'reason': reason,
          if (customReason != null) 'customReason': customReason,
        },
      );
    }
  }
}
