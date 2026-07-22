import '../../data/datasources/api_clients.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskApi _api;
  TaskRepositoryImpl([TaskApi? api]) : _api = api ?? TaskApi();

  @override
  Future<List<TaskEntity>> fetchPending() => _api.list(pendingOnly: true);

  @override
  Future<TaskEntity> createTask({
    required String title,
    String? number,
    DateTime? dueAt,
    String? callId,
  }) =>
      _api.create(title: title, number: number, dueAt: dueAt, callId: callId);

  @override
  Future<void> complete(String taskId) => _api.complete(taskId);
}
