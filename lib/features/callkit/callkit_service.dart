import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_config.dart';
import '../sip/sip_service.dart';

/// Native CallKit (iOS) / ConnectionService (Android) bridge for VoIP calls.
class CallKitService {
  CallKitService._();
  static final instance = CallKitService._();

  StreamSubscription<CallEvent?>? _eventSub;
  String? _activeCallId;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _eventSub = FlutterCallkitIncoming.onEvent.listen(_onEvent);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _initialized = false;
  }

  Future<void> showIncoming({
    required String callId,
    required String name,
    required String number,
  }) async {
    await init();
    _activeCallId = callId;
    final params = CallKitParams(
      id: callId,
      nameCaller: name.isNotEmpty ? name : number,
      appName: AppConfig.appName,
      handle: number,
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{'number': number},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'ringtone',
        backgroundColor: '#0F172A',
        actionColor: '#22C55E',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming calls',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> startOutgoing({
    required String callId,
    required String name,
    required String number,
  }) async {
    await init();
    _activeCallId = callId;
    await FlutterCallkitIncoming.startCall(
      CallKitParams(
        id: callId,
        nameCaller: name.isNotEmpty ? name : number,
        appName: AppConfig.appName,
        handle: number,
        type: 1,
        extra: <String, dynamic>{'number': number},
      ),
    );
  }

  Future<void> setConnected(String callId) async {
    await FlutterCallkitIncoming.setCallConnected(callId);
  }

  Future<void> endCall([String? callId]) async {
    final id = callId ?? _activeCallId;
    if (id == null) return;
    await FlutterCallkitIncoming.endCall(id);
    if (_activeCallId == id) _activeCallId = null;
  }

  Future<void> endAll() async {
    await FlutterCallkitIncoming.endAllCalls();
    _activeCallId = null;
  }

  void _onEvent(CallEvent? event) {
    if (event == null) return;
    final sip = SipService.instance;
    switch (event.event) {
      case Event.actionCallAccept:
        sip.answer();
        break;
      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        sip.hangup();
        break;
      case Event.actionCallToggleHold:
        final call = sip.activeCall;
        if (call?.onHold == true) {
          sip.unhold();
        } else {
          sip.hold();
        }
        break;
      default:
        debugPrint('[CallKit] event: ${event.event}');
    }
  }

  static String newCallId() => const Uuid().v4();
}
