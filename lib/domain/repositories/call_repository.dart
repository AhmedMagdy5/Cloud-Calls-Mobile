import '../entities/call_entity.dart';

abstract class CallRepository {
  Future<List<CallEntity>> fetchRemoteHistory({int limit = 50});
  Future<void> syncWrapUp({
    required String callId,
    CallDisposition? disposition,
    String? note,
    DateTime? followUpAt,
  });
}
