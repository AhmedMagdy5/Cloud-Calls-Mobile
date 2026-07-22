import '../entities/task_entity.dart';

abstract class TaskRepository {
  Future<List<TaskEntity>> fetchPending();
  Future<TaskEntity> createTask({
    required String title,
    String? number,
    DateTime? dueAt,
    String? callId,
  });
  Future<void> complete(String taskId);
}
