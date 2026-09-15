import '../../core/constants/app_config.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/queue_entity.dart';
import '../../domain/repositories/queue_repository.dart';

class QueueRepositoryImpl implements QueueRepository {
  final QueueApi _api;
  QueueRepositoryImpl([QueueApi? api]) : _api = api ?? QueueApi();

  @override
  Future<List<QueueEntity>> fetchQueues() async {
    if (!AppConfig.hasBackendConfigured) return [];
    return _api.list();
  }

  @override
  Future<void> login(String queueId) async {
    if (!AppConfig.hasBackendConfigured) return;
    await _api.login(queueId);
  }

  @override
  Future<void> logout(String queueId) async {
    if (!AppConfig.hasBackendConfigured) return;
    await _api.logout(queueId);
  }

  @override
  Future<void> setPaused(String queueId, bool paused) async {
    if (!AppConfig.hasBackendConfigured) return;
    await _api.pause(queueId, paused: paused);
  }
}
