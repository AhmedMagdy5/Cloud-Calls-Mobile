abstract class AgentRepository {
  Future<void> syncPresence({
    required String mode,
    String? reason,
    String? customReason,
  });
}
