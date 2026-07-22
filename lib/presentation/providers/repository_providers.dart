import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/agent_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/queue_repository_impl.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/repositories/agent_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/queue_repository.dart';
import '../../domain/repositories/task_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepositoryImpl());
final agentRepositoryProvider = Provider<AgentRepository>((_) => AgentRepositoryImpl());
final callRepositoryProvider = Provider<CallRepository>((_) => CallRepositoryImpl());
final contactRepositoryProvider = Provider<ContactRepository>((_) => ContactRepositoryImpl());
final customerRepositoryProvider = Provider<CustomerRepository>((_) => CustomerRepositoryImpl());
final taskRepositoryProvider = Provider<TaskRepository>((_) => TaskRepositoryImpl());
final queueRepositoryProvider = Provider<QueueRepository>((_) => QueueRepositoryImpl());

final authApiProvider = Provider((_) => AuthApi());
final voiceApiProvider = Provider((_) => VoiceApi());
final customerApiProvider = Provider((_) => CustomerApi());
final taskApiProvider = Provider((_) => TaskApi());
final queueApiProvider = Provider((_) => QueueApi());
final chatApiProvider = Provider((_) => ChatApi());
final agentAssistApiProvider = Provider((_) => AgentAssistApi());
final supervisorApiProvider = Provider((_) => SupervisorApi());
final pushApiProvider = Provider((_) => PushApi());
