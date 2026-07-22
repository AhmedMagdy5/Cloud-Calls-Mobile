import '../entities/queue_entity.dart';

abstract class QueueRepository {
  Future<List<QueueEntity>> fetchQueues();
  Future<void> login(String queueId);
  Future<void> logout(String queueId);
  Future<void> setPaused(String queueId, bool paused);
}
