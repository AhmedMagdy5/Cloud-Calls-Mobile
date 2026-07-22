import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/queue_entity.dart';
import '../../domain/entities/agent_assist_entity.dart';

/// Mirror of web project's `authApi` + `voiceFreePBXApi` (login + SIP creds fetch).
class AuthApi {
  final Dio _dio = DioClient.instance;

  Future<({UserEntity user, SipCredentials sip, String token})> login({
    required String username,
    required String password,
  }) async {
    final res = await _dio.post(AppConfig.authPath, data: {
      'username': username,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    final token = data['token'] as String;
    await StorageService.setSecure(StorageKeys.authToken, token);
    if (data['refreshToken'] != null) {
      await StorageService.setSecure(
        StorageKeys.refreshToken,
        data['refreshToken'] as String,
      );
    }

    final u = data['user'] as Map<String, dynamic>;
    final s = data['sip'] as Map<String, dynamic>;

    final user = UserEntity.fromJson(u);
    final sip = SipCredentials(
      server: (s['server'] as String?) ?? AppConfig.sipServer,
      port: (s['port'] as num?)?.toInt() ?? AppConfig.sipPort,
      transport: (s['transport'] as String?) ?? AppConfig.sipTransport,
      username: (s['username'] as String?) ?? user.extension,
      password: (s['password'] as String?) ?? '',
      authId: s['authId'] as String?,
      displayName: (s['displayName'] as String?) ?? user.name,
      wsPath: (s['path'] as String?) ?? AppConfig.sipPath,
    );
    await StorageService.setSecure(StorageKeys.sipPassword, sip.password);
    await StorageService.setSecure(StorageKeys.sipUsername, sip.username);
    await StorageService.setString(StorageKeys.userProfile, user.toJsonString());
    return (user: user, sip: sip, token: token);
  }

  Future<void> logout() async {
    try { await _dio.post('/auth/logout'); } catch (_) {}
    await StorageService.clearSecure();
    await StorageService.remove(StorageKeys.userProfile);
  }

  Future<String?> refreshToken() async {
    final refresh = await StorageService.getSecure(StorageKeys.refreshToken);
    if (refresh == null) return null;
    final res = await _dio.post(AppConfig.authRefreshPath, data: {'refreshToken': refresh});
    final token = res.data['token'] as String;
    await StorageService.setSecure(StorageKeys.authToken, token);
    return token;
  }
}

class PushApi {
  final Dio _dio = DioClient.instance;

  Future<void> registerDevice({required String token, String platform = 'mobile'}) async {
    await _dio.post(AppConfig.pushRegisterPath, data: {
      'token': token,
      'platform': platform,
    });
  }
}

/// Web CRM / browser webphone → mobile softphone command bridge.
class IntegrationApi {
  final Dio _dio = DioClient.instance;

  Future<List<Map<String, dynamic>>> pullCommands({int limit = 10}) async {
    final r = await _dio.get(
      AppConfig.integrationCommandsPath,
      queryParameters: {'limit': limit},
    );
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> ackCommand(
    String commandId, {
    required String status,
    String? error,
  }) async {
    await _dio.post('${AppConfig.integrationCommandsPath}/$commandId/ack', data: {
      'status': status,
      if (error != null) 'error': error,
    });
  }

  /// Server-side helper — send dial/hangup/etc. to an agent extension.
  Future<Map<String, dynamic>> sendCommand({
    required String targetExtension,
    required String action,
    String? number,
    String? dtmf,
    String? callId,
    String? clientRef,
    bool autoDial = true,
  }) async {
    final r = await _dio.post(AppConfig.integrationSendPath, data: {
      'targetExtension': targetExtension,
      'action': action,
      if (number != null) 'number': number,
      if (dtmf != null) 'dtmf': dtmf,
      if (callId != null) 'callId': callId,
      if (clientRef != null) 'clientRef': clientRef,
      'autoDial': autoDial,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }
}

class AgentApi {
  final Dio _dio = DioClient.instance;

  Future<void> updateStatus({
    required String mode,
    String? reason,
    String? customReason,
  }) async {
    await _dio.post(AppConfig.agentsStatusPath, data: {
      'mode': mode,
      if (reason != null) 'reason': reason,
      if (customReason != null) 'customReason': customReason,
    });
  }
}

/// Voice calls REST (history, voicemail, wrap-up).
class VoiceApi {
  final Dio _dio = DioClient.instance;

  Future<List<Map<String, dynamic>>> history({int limit = 50}) async {
    final r = await _dio.get(AppConfig.callsPath, queryParameters: {'limit': limit});
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> wrapUp({
    required String callId,
    CallDisposition? disposition,
    String? note,
    DateTime? followUpAt,
  }) async {
    await _dio.post('${AppConfig.callsPath}/$callId/wrap-up', data: {
      if (disposition != null) 'disposition': disposition.name,
      if (note != null) 'note': note,
      if (followUpAt != null) 'followUpAt': followUpAt.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> voicemail() async {
    final r = await _dio.get(AppConfig.voicemailPath);
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> contacts() async {
    final r = await _dio.get(AppConfig.contactsPath);
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> upsertContact(Map<String, dynamic> contact) async {
    await _dio.post(AppConfig.contactsPath, data: contact);
  }
}

class CustomerApi {
  final Dio _dio = DioClient.instance;

  Future<CustomerEntity?> lookupByPhone(String phone) async {
    try {
      final r = await _dio.get(AppConfig.customersPath, queryParameters: {'phone': phone});
      final data = r.data;
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        return CustomerEntity.fromJson(data);
      }
      if (data is Map && data['customer'] != null) {
        return CustomerEntity.fromJson(Map<String, dynamic>.from(data['customer'] as Map));
      }
    } catch (_) {}
    return null;
  }
}

class TaskApi {
  final Dio _dio = DioClient.instance;

  Future<List<TaskEntity>> list({bool pendingOnly = true}) async {
    final r = await _dio.get(AppConfig.tasksPath, queryParameters: {
      if (pendingOnly) 'status': 'pending',
    });
    return (r.data['items'] as List)
        .map((e) => TaskEntity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<TaskEntity> create({
    required String title,
    String? number,
    DateTime? dueAt,
    String? callId,
  }) async {
    final r = await _dio.post(AppConfig.tasksPath, data: {
      'title': title,
      if (number != null) 'number': number,
      if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
      if (callId != null) 'callId': callId,
    });
    return TaskEntity.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> complete(String taskId) async {
    await _dio.patch('${AppConfig.tasksPath}/$taskId', data: {'status': 'done'});
  }
}

class QueueApi {
  final Dio _dio = DioClient.instance;

  Future<List<QueueEntity>> list() async {
    final r = await _dio.get(AppConfig.queuesPath);
    return (r.data['items'] as List)
        .map((e) => QueueEntity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> login(String queueId) async {
    await _dio.post('${AppConfig.queuesPath}/$queueId/login');
  }

  Future<void> logout(String queueId) async {
    await _dio.post('${AppConfig.queuesPath}/$queueId/logout');
  }

  Future<void> pause(String queueId, {required bool paused}) async {
    await _dio.post('${AppConfig.queuesPath}/$queueId/pause', data: {'paused': paused});
  }
}

class ChatApi {
  final Dio _dio = DioClient.instance;

  Future<List<ChatMessageEntity>> messages({int limit = 50}) async {
    final r = await _dio.get(AppConfig.chatPath, queryParameters: {'limit': limit});
    return (r.data['items'] as List)
        .map((e) => ChatMessageEntity.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ChatMessageEntity> send({required String text, String? toUserId}) async {
    final r = await _dio.post(AppConfig.chatPath, data: {
      'text': text,
      if (toUserId != null) 'toUserId': toUserId,
    });
    return ChatMessageEntity.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

class AgentAssistApi {
  final Dio _dio = DioClient.instance;

  Future<AgentAssistSummary?> summarizeCall(String callId) async {
    try {
      final r = await _dio.post('${AppConfig.agentAssistPath}/summarize', data: {'callId': callId});
      return AgentAssistSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> searchKnowledge(String query) async {
    try {
      final r = await _dio.get('${AppConfig.agentAssistPath}/knowledge', queryParameters: {'q': query});
      return (r.data['results'] as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<List<TranscriptChunk>> fetchTranscript(String callId) async {
    try {
      final r = await _dio.get('${AppConfig.agentAssistPath}/transcript/$callId');
      return (r.data['chunks'] as List)
          .map((e) => TranscriptChunk.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class SupervisorApi {
  final Dio _dio = DioClient.instance;

  Future<List<Map<String, dynamic>>> agentBoard() async {
    final r = await _dio.get('${AppConfig.supervisorPath}/agents');
    return (r.data['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> monitor({required String agentId, required String mode}) async {
    await _dio.post('${AppConfig.supervisorPath}/monitor', data: {
      'agentId': agentId,
      'mode': mode,
    });
  }
}
