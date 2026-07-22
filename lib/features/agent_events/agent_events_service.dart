import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';

/// WebSocket-style agent events hub (connects when backend URL is configured).
class AgentEventsService {
  AgentEventsService._();
  static final instance = AgentEventsService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _controller.stream;
  Timer? _poll;

  void start() {
    if (_poll != null) return;
    if (!AppConfig.hasBackendConfigured) {
      debugPrint('[AgentEvents] backend not configured — polling disabled');
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      _controller.add({'type': 'heartbeat', 'at': DateTime.now().toIso8601String()});
    });
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
