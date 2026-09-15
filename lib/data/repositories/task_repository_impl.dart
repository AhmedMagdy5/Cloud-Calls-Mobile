import '../../core/constants/app_config.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskApi _api;
  TaskRepositoryImpl([TaskApi? api]) : _api = api ?? TaskApi();

  @override
  Future<List<TaskEntity>> fetchPending() async {
    if (!AppConfig.hasBackendConfigured) return [];
    return _api.list(pendingOnly: true);
  }

  @override
  Future<TaskEntity> createTask({
    required String title,
    String? number,
    DateTime? dueAt,
    String? callId,
  }) {
    if (!AppConfig.hasBackendConfigured) {
      throw StateError('Backend API is not configured.');
    }
    return _api.create(title: title, number: number, dueAt: dueAt, callId: callId);
  }

  @override
  Future<void> complete(String taskId) async {
    if (!AppConfig.hasBackendConfigured) return;
    await _api.complete(taskId);
  }
}
