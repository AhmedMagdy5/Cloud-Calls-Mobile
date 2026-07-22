import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_entity.dart';
import 'auth_provider.dart';

/// Role-based feature gates for enterprise deployments.
class RbacState {
  final UserEntity? user;
  const RbacState(this.user);

  bool get canUseSupervisorTools => user?.isSupervisor == true;
  bool get canMonitorAgents => user?.isSupervisor == true;
  bool get canViewRecordings => user?.isSupervisor == true || user?.role == 'qa';
  bool get canManageQueues => user != null;
}

final rbacProvider = Provider<RbacState>((ref) {
  final user = ref.watch(authProvider).user;
  return RbacState(user);
});
