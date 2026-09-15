import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/notification_service.dart';
import '../../data/datasources/api_clients.dart';
import '../integration/webphone_integration_service.dart';
import '../sip/sip_service.dart';

/// FCM push-to-wake for incoming calls and agent events.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready || Firebase.apps.isEmpty) return;
    if (!AppConfig.enablePushCalls) return;

    final fcm = FirebaseMessaging.instance;
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.onMessage.listen(_handleForeground);

    final initial = await fcm.getInitialMessage();
    if (initial != null) _handleMessage(initial);

    _ready = true;
  }

  /// Register device token with backend after login.
  Future<void> registerToken() async {
    if (Firebase.apps.isEmpty || !AppConfig.hasBackendConfigured) return;
    final token = NotificationService.instance.token ??
        await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await PushApi().registerDevice(token: token);
    } catch (e) {
      debugPrint('[Push] registerToken failed: $e');
    }
  }

  void _handleForeground(RemoteMessage msg) => _dispatch(msg.data);

  void _handleMessage(RemoteMessage msg) => _dispatch(msg.data);

  void _dispatch(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'incoming_call':
        _wakeForIncomingCall(data);
        break;
      case 'agent_event':
        debugPrint('[Push] agent_event: $data');
        break;
      case 'webphone_command':
        unawaited(WebphoneIntegrationService.instance.handlePushPayload(data));
        break;
      default:
        debugPrint('[Push] unknown: $data');
    }
  }

  Future<void> _wakeForIncomingCall(Map<String, dynamic> data) async {
    final number = data['number']?.toString() ?? data['caller']?.toString() ?? '';
    final name = data['name']?.toString() ?? number;
    if (number.isEmpty) return;

    // Wake SIP so a real INVITE can land. Do not fabricate CallKit UI —
    // answering a fake call with no SIP session hangs the softphone.
    await SipService.instance.ensureConnected();
    await NotificationService.instance.showIncomingCall(name: name, number: number);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[Push] background: ${message.data}');
  if (message.data['type'] == 'incoming_call') {
    final number = message.data['number']?.toString() ?? '';
    final name = message.data['name']?.toString() ?? number;
    if (number.isNotEmpty) {
      await NotificationService.instance.init();
      await NotificationService.instance.showIncomingCall(name: name, number: number);
    }
  }
}
