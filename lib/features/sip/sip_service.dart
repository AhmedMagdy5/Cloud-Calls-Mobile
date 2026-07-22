import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../data/call_history_store.dart';
import '../../data/contacts_store.dart';
import '../../data/parked_call_store.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/parked_call_entity.dart';
import '../../core/services/notification_service.dart';
import '../callkit/callkit_service.dart';
import '../../features/caller_id/caller_lookup_service.dart';
import '../../features/presence/mobile_presence_service.dart';
import 'ringtone_player.dart';
import 'headset_controls.dart';



/// User-controlled presence mode (separate from SIP registration state).
/// - online: register + accept incoming + allow outgoing.
/// - dnd:    register + allow outgoing, but auto-reject any incoming call.
/// - offline: do not register; block outgoing calls and incoming entirely.
enum PresenceMode { online, dnd, offline }

/// Human-readable registration status surfaced to the UI.
enum SipStatus { idle, registering, registered, unregistered, failed, reconnecting }

/// Production SIP wrapper — registers, manages calls, audio routing, DTMF,
/// hold, transfer, with auto-retry on failure and full call-history logging.
class SipService extends ChangeNotifier implements SipUaHelperListener {
  SipService._();
  static final instance = SipService._();

  final SIPUAHelper _ua = SIPUAHelper();
  SipCredentials? _creds;
  RegistrationState _regState = RegistrationState(state: RegistrationStateEnum.NONE);
  SipStatus _status = SipStatus.idle;
  String? _lastError;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _uaRestarting = false;
  PresenceMode _presence = PresenceMode.online;
  static const _kPresenceKey = 'sip_presence_mode';
  static const _kBreakReasonKey = 'sip_break_reason';
  static const _kBreakCustomKey = 'sip_break_custom_reason';
  String? _breakReason;
  String? _breakCustomReason;
  final Map<String, Call> _calls = {};
  CallEntity? _activeCall;
  String? _foregroundCallId;
  bool _openActiveAfterHeldResume = false;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _speakerOn = false;
  bool _muted = false;

  // ----- Public state -----
  RegistrationState get registrationState => _regState;
  SipStatus get status => _status;
  String? get lastError => _lastError;
  bool get isRegistered => _status == SipStatus.registered;
  CallEntity? get activeCall => _activeCall;
  bool get hasHeldCalls => ParkedCallStore.instance.items.isNotEmpty;
  bool get openActiveAfterHeldResume => _openActiveAfterHeldResume;
  void consumeOpenActiveAfterHeldResume() => _openActiveAfterHeldResume = false;
  SIPUAHelper get helper => _ua;
  SipCredentials? get credentials => _creds;
  bool get speakerOn => _speakerOn;
  bool get headsetConnected => HeadsetControls.instance.bluetoothConnected;

  void refreshHeadsetState() => notifyListeners();
  PresenceMode get presence => _presence;
  String? get breakReason => _breakReason;
  String? get breakCustomReason => _breakCustomReason;
  String? get breakReasonLabel =>
      _breakCustomReason != null && _breakCustomReason!.isNotEmpty
          ? _breakCustomReason
          : _breakReason;

  String get statusLabel {
    if (_presence == PresenceMode.offline) return 'Offline';
    if (_presence == PresenceMode.dnd && _status == SipStatus.registered) return 'Do Not Disturb';
    switch (_status) {
      case SipStatus.idle: return 'Offline';
      case SipStatus.registering: return 'Registering…';
      case SipStatus.registered: return 'Online';
      case SipStatus.unregistered: return 'Unregistered';
      case SipStatus.reconnecting: return 'Reconnecting…';
      case SipStatus.failed: return 'Failed${_lastError != null ? ' — $_lastError' : ''}';
    }
  }

  /// Load the persisted presence mode (call once at app start before connect()).
  void loadPresence() {
    final raw = StorageService.getString(_kPresenceKey);
    if (raw != null) {
      _presence = PresenceMode.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PresenceMode.online,
      );
    }
    _breakReason = StorageService.getString(_kBreakReasonKey);
    _breakCustomReason = StorageService.getString(_kBreakCustomKey);
  }

  /// Change presence mode. Offline → unregister; Online/DND → ensure registered.
  /// [reason] / [customReason] are tagged onto the break when leaving Online.
  Future<void> setPresence(
    PresenceMode mode, {
    String? reason,
    String? customReason,
  }) async {
    if (_presence == mode) return;
    _presence = mode;
    await StorageService.setString(_kPresenceKey, mode.name);
    if (mode == PresenceMode.online) {
      _breakReason = null;
      _breakCustomReason = null;
      await StorageService.remove(_kBreakReasonKey);
      await StorageService.remove(_kBreakCustomKey);
    } else {
      _breakReason = reason;
      _breakCustomReason = customReason;
      if (reason != null) {
        await StorageService.setString(_kBreakReasonKey, reason);
      }
      if (customReason != null && customReason.isNotEmpty) {
        await StorageService.setString(_kBreakCustomKey, customReason);
      } else {
        await StorageService.remove(_kBreakCustomKey);
      }
    }
    notifyListeners();
    unawaited(MobilePresenceService.instance.onPresenceChanged());
    if (mode == PresenceMode.offline) {
      _retryTimer?.cancel();
      try { _ua.unregister(); } catch (_) {}
      try { _ua.stop(); } catch (_) {}
      _setStatus(SipStatus.unregistered);
    } else {
      // online or dnd → make sure we are connected
      if (_creds != null && !isRegistered) {
        _retryAttempt = 0;
        await _startUa();
      } else {
        notifyListeners();
      }
    }
  }

  // ----- Lifecycle -----
  Future<void> connect(SipCredentials creds) async {
    _creds = creds;
    _retryAttempt = 0;
    if (_presence == PresenceMode.offline) {
      _setStatus(SipStatus.unregistered);
      return;
    }
    await _startUa();
  }

  /// Soft restart after settings change — keeps listener/creds, avoids reconnect loops.
  Future<void> reapplyCredentials(SipCredentials creds) async {
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _creds = creds;
    if (_presence == PresenceMode.offline) {
      _setStatus(SipStatus.unregistered);
      return;
    }
    _uaRestarting = true;
    _setStatus(SipStatus.registering);
    try {
      try {
        _ua.stop();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _startUa(skipStop: true);
    } catch (e, st) {
      _uaRestarting = false;
      debugPrint('[SIP] reapply error: $e\n$st');
      rethrow;
    }
  }

  static bool credentialsEqual(SipCredentials a, SipCredentials b) {
    return a.server == b.server &&
        a.port == b.port &&
        a.transport == b.transport &&
        a.username == b.username &&
        a.password == b.password &&
        a.authId == b.authId &&
        a.wsPath == b.wsPath &&
        a.outboundProxy == b.outboundProxy;
  }

  Future<void> _startUa({bool skipStop = false}) async {
    final creds = _creds;
    if (creds == null) return;
    _setStatus(SipStatus.registering);

    // Build the WS URL. sip_ua supports WebSocket transports only.
    // - ws/wss  → use exactly what the user configured
    // - udp/tcp/tls (unsupported by sip_ua) → fallback to ws on same host:
    //     * port 5060 → wss://host:8089/ws  (Asterisk/FreePBX default WSS)
    //     * other ports → ws://host:port/ws  (respect user port, plain WS)
    String wsUrl;
    if (creds.isWebSocket) {
      wsUrl = creds.wsUri;
    } else if (creds.port == 5060) {
      wsUrl = 'wss://${creds.server}:8089${creds.wsPath}';
    } else {
      wsUrl = 'ws://${creds.server}:${creds.port}${creds.wsPath}';
    }
    debugPrint('[SIP] REGISTER → ${creds.sipUri} via $wsUrl (transport=${creds.transport})');

    try {
      if (!skipStop) {
        _uaRestarting = true;
        // Stop any previous UA instance cleanly before starting a new one —
        // prevents duplicate sockets / "transport already connected" loops.
        try { _ua.stop(); } catch (_) {}
      }
      try { _ua.removeSipUaHelperListener(this); } catch (_) {}

      final settings = UaSettings()
        ..uri = creds.sipUri
        ..authorizationUser = creds.authId ?? creds.username
        ..password = creds.password
        ..displayName = creds.displayName ?? creds.username
        ..userAgent = '${AppConfig.appName}/${AppConfig.appVersion}'
        ..dtmfMode = DtmfMode.RFC2833
        ..iceServers = _buildIceServers(creds)
        ..register = true
        ..register_expires = 600

        ..webSocketUrl = wsUrl
        ..webSocketSettings.allowBadCertificate = true
        ..transportType = TransportType.WS;

      _ua.addSipUaHelperListener(this);
      await _ua.start(settings);
    } catch (e, st) {
      _uaRestarting = false;
      debugPrint('[SIP] start error: $e\n$st');
      _lastError = e.toString();
      _setStatus(SipStatus.failed);
      _scheduleRetry();
    }
  }

  List<Map<String, String>> _buildIceServers(SipCredentials c) {
    if (!c.iceEnabled) return const [];
    final list = <Map<String, String>>[];
    if (c.stunServer.isNotEmpty) list.add({'urls': c.stunServer});
    if (c.turnServer != null && c.turnServer!.isNotEmpty) {
      final turn = <String, String>{'urls': c.turnServer!};
      if (c.turnUsername != null) turn['username'] = c.turnUsername!;
      if (c.turnPassword != null) turn['credential'] = c.turnPassword!;
      list.add(turn);
    }
    return list;
  }

  Future<void> register() async => _startUa();
  Future<void> reRegister() async { debugPrint('[SIP] re-register'); _ua.register(); }
  Future<void> unregister() async {
    _retryTimer?.cancel();
    _ua.unregister();
    _setStatus(SipStatus.unregistered);
  }
  Future<void> disconnect() async {
    await MobilePresenceService.instance.stop(logout: false);
    _retryTimer?.cancel();
    _ua.stop();
    _ua.removeSipUaHelperListener(this);
    _creds = null;
    _calls.clear();
    _activeCall = null;
    _setStatus(SipStatus.idle);
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return; // already pending
    if (_creds == null) return;
    if (_presence == PresenceMode.offline) return; // user is offline by choice
    _retryAttempt++;
    // Exponential backoff capped at 30s: 5, 10, 15, 20, 30…
    final secs = [5, 10, 15, 20, 30];
    final delay = Duration(seconds: secs[_retryAttempt.clamp(1, secs.length) - 1]);
    debugPrint('[SIP] retry #$_retryAttempt in ${delay.inSeconds}s');
    _setStatus(SipStatus.reconnecting);
    _retryTimer = Timer(delay, () => _startUa());
  }

  /// Public hook — call when connectivity returns or app resumes.
  Future<void> ensureConnected() async {
    if (_creds == null) return;
    if (_presence == PresenceMode.offline) return;
    // Don't interrupt healthy / in-progress states — this caused needless
    // reconnect loops every time the UI rebuilt or the app resumed.
    if (_status == SipStatus.registered ||
        _status == SipStatus.registering ||
        _status == SipStatus.reconnecting) return;
    debugPrint('[SIP] ensureConnected → restarting UA');
    _retryTimer?.cancel();
    await _startUa();
  }

  void _setStatus(SipStatus s) { _status = s; notifyListeners(); }

  Future<void> _ensureMicPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final r = await Permission.microphone.request();
        if (!r.isGranted) {
          throw StateError('Microphone permission denied');
        }
      }
    } catch (e) {
      debugPrint('[SIP] mic permission error: $e');
      rethrow;
    }
  }

  // ----- Call control -----
  Map<String, dynamic> _audioOverrides() => <String, dynamic>{
        'mediaConstraints': <String, dynamic>{
          'audio': <String, dynamic>{
            'echoCancellation': _creds?.echoCancellation ?? true,
            'noiseSuppression': _creds?.noiseSuppression ?? true,
            'autoGainControl': true,
          },
          'video': false,
        },
        'rtcOfferConstraints': <String, dynamic>{
          'mandatory': <String, dynamic>{
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': false,
          },
          'optional': <dynamic>[],
        },
        'rtcAnswerConstraints': <String, dynamic>{
          'mandatory': <String, dynamic>{
            'OfferToReceiveAudio': true,
            'OfferToReceiveVideo': false,
          },
          'optional': <dynamic>[],
        },
      };

  Map<String, dynamic> _audioAnswerOptions() {
    final opts = _ua.buildCallOptions(true);
    opts['mediaConstraints'] = <String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': _creds?.echoCancellation ?? true,
        'noiseSuppression': _creds?.noiseSuppression ?? true,
        'autoGainControl': true,
      },
      'video': false,
    };
    opts['rtcOfferConstraints'] = <String, dynamic>{
      'mandatory': <String, dynamic>{
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
      'optional': <dynamic>[],
    };
    opts['rtcAnswerConstraints'] = <String, dynamic>{
      'mandatory': <String, dynamic>{
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
      'optional': <dynamic>[],
    };
    return opts;
  }

  bool _isLocalOriginator(Object? originator) {
    final value = originator?.toString().toLowerCase() ?? '';
    return originator == Originator.local ||
        value == 'local' ||
        value.endsWith('.local');
  }

  bool _isRemoteOriginator(Object? originator) {
    final value = originator?.toString().toLowerCase() ?? '';
    return originator == Originator.remote ||
        value == 'remote' ||
        value.endsWith('.remote');
  }

  String _callKey(Call call) => call.id ?? call.hashCode.toString();

  String _parseSipUser(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var value = raw.trim();
    if (value.startsWith('"')) {
      final end = value.indexOf('"', 1);
      if (end > 1) return value.substring(1, end);
    }
    value = value.replaceAll(RegExp(r'^sip:'), '');
    value = value.split(';').first;
    value = value.split('@').first;
    return value.trim();
  }

  String _extractRemoteNumber(Call call) {
    final parsed = _parseSipUser(call.remote_identity);
    if (parsed.isNotEmpty) return parsed;
    if (_activeCall != null && _activeCall!.number.isNotEmpty) {
      return _activeCall!.number;
    }
    return '';
  }

  String? _extractDisplayName(Call call) {
    final name = call.remote_display_name?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (_activeCall?.displayName?.isNotEmpty == true) {
      return _activeCall!.displayName;
    }
    return null;
  }

  bool _isUnansweredIncomingTerminal(CallEntity call) =>
      call.direction == CallDirection.incoming &&
      call.answeredAt == null &&
      call.status.isTerminal;

  void _markCurrentCallConnected({DateTime? at}) {
    final call = _activeCall;
    if (call == null) return;
    _activeCall = call.copyWith(
      status: CallStatus.active,
      answeredAt: call.answeredAt ?? at ?? DateTime.now(),
      onHold: false,
    );
    RingtonePlayer.instance.stop();
    NotificationService.instance.cancelIncomingCall();
    final id = _activeCall?.id;
    if (id != null) unawaited(CallKitService.instance.setConnected(id));
    notifyListeners();
  }

  Future<void> makeCall(String number) async {
    if (_presence == PresenceMode.offline) {
      throw StateError('You are offline. Switch to Online to make calls.');
    }
    await _ensureMicPermission();
    if (!isRegistered) {
      debugPrint('[SIP] makeCall: not registered → forcing re-register');
      await _startUa();
      // Wait briefly for registration.
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (!isRegistered && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (!isRegistered) throw StateError('SIP not registered — check server / transport');
    }
    debugPrint('[SIP] makeCall → $number');
    if (!hasHeldCalls) {
      _localStream = null;
      _remoteStream = null;
    }
    final started = await _ua.call(
      number,
      voiceOnly: true,
      customOptions: _audioOverrides(),
    );
    if (!started) throw StateError('Call could not be started');
    final callId = CallKitService.newCallId();
    unawaited(CallKitService.instance.startOutgoing(
      callId: callId,
      name: number,
      number: number,
    ));

    // NOTE: Asterisk sends 183 Session Progress with early media (ringback tone)
    // BEFORE the callee answers. Remote audio is therefore NOT a reliable
    // signal that the call is active. We rely strictly on ACCEPTED/CONFIRMED
    // (SIP 200 OK) to mark the call as connected — handled in callStateChanged.
  }

  void acceptCall() => answer();
  void rejectCall() => hangup();
  void answer() async {
    Call? call;
    if (_foregroundCallId != null) {
      call = _calls[_foregroundCallId];
    } else {
      for (final e in _calls.entries) {
        if (!_isHeldLocally(e.key)) {
          call = e.value;
          break;
        }
      }
    }
    if (call == null) return;
    await _ensureMicPermission();
    call.answer(_audioAnswerOptions());
  }
  void hangup() {
    final id = _foregroundCallId ?? _activeCall?.id;
    final call = id != null ? _calls[id] : null;
    if (id == null) return;
    try { call?.hangup(); } catch (_) {}
    // Safety net: if no ENDED/FAILED event arrives, force-clear locally.
    Timer(const Duration(seconds: 2), () {
      final cur = _activeCall;
      if (cur == null || cur.id != id) return;
      if (cur.status.isTerminal) return;
      final mapped = cur.answeredAt == null &&
              cur.direction == CallDirection.incoming
          ? CallStatus.missed
          : (cur.answeredAt == null
              ? CallStatus.canceled
              : CallStatus.ended);
      _activeCall = cur.copyWith(
        status: mapped,
        endedAt: DateTime.now(),
        endReason: mapped == CallStatus.canceled ? 'Cancelled' : null,
      );
      try { CallHistoryStore.instance.upsert(_activeCall!); } catch (_) {}
      _calls.remove(id);
      if (_calls.isEmpty) _cleanupMedia();
      if (_foregroundCallId == id) _foregroundCallId = null;
      RingtonePlayer.instance.stop();
      NotificationService.instance.cancelIncomingCall();
      unawaited(CallKitService.instance.endCall(id));
      notifyListeners();
      Timer(const Duration(milliseconds: 500), () {
        if (_activeCall?.id == id) {
          _activeCall = null;
          notifyListeners();
        }
      });
    });
  }
  void hangUp() => hangup();

  Call? get _foregroundSipCall =>
      _foregroundCallId != null ? _calls[_foregroundCallId] : null;

  bool _isHeldLocally(String callId) =>
      ParkedCallStore.instance.items.any((p) => p.id == callId);

  Call? _sipCallForHeld(ParkedCallEntity held) {
    if (_calls.containsKey(held.id)) return _calls[held.id];
    for (final e in _calls.entries) {
      final remote = _extractRemoteNumber(e.value);
      if (CallerLookupService.numbersMatch(remote, held.customerNumber)) {
        return e.value;
      }
    }
    return null;
  }

  String? _callIdForSipCall(Call call) {
    final key = _callKey(call);
    if (_calls.containsKey(key)) return key;
    for (final e in _calls.entries) {
      if (identical(e.value, call)) return e.key;
    }
    return key;
  }

  Future<void> _tryAutoResumeHeldCall() async {
    if (ParkedCallStore.instance.items.isEmpty) return;
    if (_foregroundCallId != null &&
        _activeCall != null &&
        !_activeCall!.status.isTerminal) {
      return;
    }

    final held = ParkedCallStore.instance.items.first;
    final sipCall = _sipCallForHeld(held);
    if (sipCall == null) {
      await ParkedCallStore.instance.remove(held.id);
      notifyListeners();
      return;
    }

    final sipKey = _callIdForSipCall(sipCall) ?? held.id;
    await resumeHeldCall(sipKey, heldMeta: held);
    _openActiveAfterHeldResume = true;
    notifyListeners();
  }

  /// Hang up a locally held call and remove it from the waiting list.
  void hangupHeldCall(String callId) {
    final held = ParkedCallStore.instance.findById(callId);
    final sipCall = held != null ? _sipCallForHeld(held) : _calls[callId];
    try {
      sipCall?.hangup();
    } catch (_) {}
    unawaited(ParkedCallStore.instance.remove(callId));
    notifyListeners();
  }

  bool _shouldApplyAsForeground(String key, CallState state) {
    if (_foregroundCallId != null) return key == _foregroundCallId;
    if (_isHeldLocally(key)) return false;
    if (_foregroundCallId == null) {
      return state.state != CallStateEnum.HOLD;
    }
    return false;
  }

  void hold() => _foregroundSipCall?.hold();
  void unhold() => _foregroundSipCall?.unhold();
  void mute(bool audio) {
    final call = _foregroundSipCall;
    if (call == null) return;
    if (audio) {
      call.mute(true, false);
    } else {
      call.unmute(true, false);
    }
    _muted = audio;
    if (_activeCall != null) _activeCall = _activeCall!.copyWith(muted: audio);
    notifyListeners();
  }
  void sendDtmf(String tone) => _foregroundSipCall?.sendDTMF(tone);
  void transfer(String target) => _foregroundSipCall?.refer(target);

  /// Hold the current call locally so the agent can dial another number.
  void parkCurrentCall() {
    final id = _foregroundCallId ?? _activeCall?.id;
    if (id == null || _activeCall == null) {
      throw StateError('No active call to park');
    }
    if (_activeCall!.answeredAt == null) {
      throw StateError('Call must be connected before parking');
    }
    final sipCall = _calls[id];
    if (sipCall == null) throw StateError('Call session lost');

    sipCall.hold();
    unawaited(ParkedCallStore.instance.add(ParkedCallEntity(
      id: id,
      customerNumber: _activeCall!.number,
      customerName: _activeCall!.displayName,
      slot: id,
      parkedAt: DateTime.now(),
      startedAt: _activeCall!.startedAt,
      answeredAt: _activeCall!.answeredAt,
      direction: _activeCall!.direction,
    )));

    _foregroundCallId = null;
    _activeCall = null;
    notifyListeners();
  }

  /// Resume a locally held (parked) call.
  Future<void> resumeHeldCall(String callId, {ParkedCallEntity? heldMeta}) async {
    final held = heldMeta ?? ParkedCallStore.instance.findById(callId);
    final sipCall = held != null ? _sipCallForHeld(held) : _calls[callId];
    if (sipCall == null) {
      await ParkedCallStore.instance.remove(callId);
      throw StateError('Held call is no longer active');
    }

    final sipKey = _callIdForSipCall(sipCall) ?? callId;

    final fg = _foregroundCallId;
    if (fg != null && fg != sipKey) {
      final live = _activeCall;
      if (live != null && !live.status.isTerminal) {
        _calls[fg]?.hold();
      }
    }

    if (held != null) {
      _activeCall = held.toCallEntity().copyWith(
        status: CallStatus.active,
        onHold: false,
      );
    }
    _foregroundCallId = sipKey;
    sipCall.unhold();
    await ParkedCallStore.instance.remove(sipKey);
    if (held != null && held.id != sipKey) {
      await ParkedCallStore.instance.remove(held.id);
    }
    notifyListeners();
  }

  /// Route audio to loudspeaker (true) or earpiece (false).
  Future<void> setSpeaker(bool on) async {
    _speakerOn = on;
    await _refreshCallAudioRoute();
    notifyListeners();
  }

  Future<void> _refreshCallAudioRoute() async {
    if (_remoteStream == null && _localStream == null) return;
    try {
      await HeadsetControls.instance.ensureActiveForCall();
      await Helper.setSpeakerphoneOn(_speakerOn);
      for (final stream in [_remoteStream, _localStream]) {
        if (stream == null) continue;
        for (final track in stream.getAudioTracks()) {
          track.enabled = stream == _localStream ? !_muted : true;
          track.enableSpeakerphone(_speakerOn);
        }
      }
    } catch (e) {
      debugPrint('[SIP] audio route refresh: $e');
    }
  }

  void _scheduleCallAudioRefresh() {
    unawaited(_refreshCallAudioRoute());
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), _refreshCallAudioRoute),
    );
  }

  void _cleanupMedia() {
    if (_calls.isNotEmpty || hasHeldCalls) return;
    try { _localStream?.getTracks().forEach((t) => t.stop()); } catch (_) {}
    try { _remoteStream?.getTracks().forEach((t) => t.stop()); } catch (_) {}
    _localStream = null;
    _remoteStream = null;
    _speakerOn = false;
    _muted = false;
    HeadsetControls.instance.detach();
  }

  void _syncHeadsetControls() {
    final call = _activeCall;
    if (call == null ||
        call.status.isTerminal ||
        call.status == CallStatus.idle) {
      HeadsetControls.instance.detach();
      return;
    }

    final incomingRinging = call.direction == CallDirection.incoming &&
        call.answeredAt == null &&
        (call.status == CallStatus.ringing ||
            call.status == CallStatus.connecting);

    HeadsetControls.instance.attach(
      isIncomingRinging: incomingRinging,
      onAnswer: answer,
      onHangup: hangup,
      onReject: hangup,
      onBluetoothConnected: () async {
        await setSpeaker(false);
      },
    );
    HeadsetControls.instance.updateIncomingRinging(incomingRinging);
  }

  // ----- SipUaHelperListener -----
  @override
  void registrationStateChanged(RegistrationState state) {
    _regState = state;
    debugPrint('[SIP] registrationStateChanged → ${state.state} ${state.cause ?? ''}');
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _lastError = null;
        _retryAttempt = 0;
        _retryTimer?.cancel();
        _uaRestarting = false;
        _setStatus(SipStatus.registered);
        unawaited(MobilePresenceService.instance.onSipRegistered());
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _uaRestarting = false;
        _lastError = state.cause?.cause ?? 'Registration failed';
        _setStatus(SipStatus.failed);
        _scheduleRetry();
        break;
      case RegistrationStateEnum.UNREGISTERED:
        _setStatus(SipStatus.unregistered);
        break;
      case RegistrationStateEnum.NONE:
      default:
        notifyListeners();
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    final key = _callKey(call);
    final callId = key;
    _calls[key] = call;
    final dir = call.direction == Direction.incoming
        ? CallDirection.incoming
        : CallDirection.outgoing;

    // Auto-reject on incoming new call when blocked, DND, or offline.
    if (dir == CallDirection.incoming &&
        (state.state == CallStateEnum.CALL_INITIATION ||
            state.state == CallStateEnum.PROGRESS)) {
      final remote = _extractRemoteNumber(call);
      final blocked = ContactsStore.instance.isBlocked(remote);
      final byPresence = _presence == PresenceMode.dnd || _presence == PresenceMode.offline;
      if (blocked || byPresence) {
        debugPrint('[SIP] Auto-rejecting ($remote) — blocked=$blocked presence=$_presence');
        try { call.hangup(); } catch (_) {}
        _calls.remove(key);
        return;
      }
    }


    // Capture media streams as they arrive.
    if (state.stream != null && _shouldApplyAsForeground(key, state)) {
      if (_isLocalOriginator(state.originator)) {
        _localStream = state.stream;
        for (final track in _localStream!.getAudioTracks()) {
          track.enabled = !_muted;
        }
        debugPrint('[SIP] local audio tracks: ${_localStream!.getAudioTracks().length}');
      } else if (_isRemoteOriginator(state.originator)) {
        _remoteStream = state.stream;
        for (final track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
        }
        debugPrint('[SIP] remote audio tracks: ${_remoteStream!.getAudioTracks().length}');
        _scheduleCallAudioRefresh();
      } else {
        debugPrint('[SIP] stream with unknown originator: ${state.originator}');
      }
    }

    CallStatus mapped;
    DateTime? answeredAt =
        _activeCall?.id == callId ? _activeCall?.answeredAt : null;
    DateTime? endedAt;
    String? endReason;
    int? hangupCode;
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.CONNECTING:
        mapped = CallStatus.connecting; break;
      case CallStateEnum.PROGRESS:
        mapped = CallStatus.ringing; break;
      case CallStateEnum.STREAM:
        // Remote media during PROGRESS is Asterisk early media (183 ringback),
        // NOT an answer. Keep the previous status (ringing/connecting) and
        // wait for ACCEPTED/CONFIRMED (200 OK) before marking active.
        // Stop the local ringback so the PBX-supplied tone is audible.
        if (_isRemoteOriginator(state.originator)) {
          if (answeredAt != null) {
            mapped = CallStatus.active;
          } else {
            mapped = _activeCall?.status ?? CallStatus.ringing;
            if (dir == CallDirection.outgoing) {
              RingtonePlayer.instance.stop();
            }
          }
        } else {
          mapped = _activeCall?.status ?? CallStatus.connecting;
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        mapped = CallStatus.active;
        answeredAt ??= DateTime.now();
        // Tone stops as soon as call connects.
        RingtonePlayer.instance.stop();
        NotificationService.instance.cancelIncomingCall();
        _scheduleCallAudioRefresh();
        break;
      case CallStateEnum.HOLD: mapped = CallStatus.held; break;
      case CallStateEnum.UNHOLD: mapped = CallStatus.active; break;
      case CallStateEnum.MUTED:
        _muted = state.audio == true;
        mapped = _activeCall?.status ?? CallStatus.active;
        break;
      case CallStateEnum.UNMUTED:
        if (state.audio == true) _muted = false;
        mapped = _activeCall?.status ?? CallStatus.active;
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        final res = _mapHangupCause(
          state: state.state,
          cause: state.cause,
          originator: state.originator,
          direction: dir,
          answered: answeredAt != null,
        );
        mapped = res.$1;
        endReason = res.$2;
        hangupCode = res.$3;
        endedAt = DateTime.now();
        if (answeredAt == null &&
            dir == CallDirection.incoming &&
            (mapped == CallStatus.ended ||
                mapped == CallStatus.canceled ||
                mapped == CallStatus.noAnswer)) {
          mapped = CallStatus.missed;
          endReason ??= 'Missed call';
        }
        RingtonePlayer.instance.stop();
        NotificationService.instance.cancelIncomingCall();
        unawaited(CallKitService.instance.endCall(callId));
        break;
      default:
        mapped = CallStatus.ringing;
    }

    // Once a call has been answered, never let a late PROGRESS/local STREAM or
    // an unhandled SIP event push the UI back to Ringing/Dialing.
    if (answeredAt != null &&
        (mapped == CallStatus.ringing || mapped == CallStatus.connecting)) {
      mapped = CallStatus.active;
    }

    // Asterisk hangup-cause / response mapping reminder:
    //   180 Ringing             → PROGRESS (no media) → ringing
    //   183 Session Progress    → PROGRESS + early media → still ringing
    //   200 OK                  → ACCEPTED/CONFIRMED → active
    //   486/600 / Q.850 17      → busy
    //   603 / 403 / 401 / 407   → declined (call rejected)
    //   408 / 480 / 487         → noAnswer (or canceled if local CANCEL)
    //   404 / 410 / 484 / 485   → unavailable (number not found / out of order)
    // Do NOT promote to active based on remote media alone — 183 carries
    // ringback tone from the PBX before the callee answers.

    // Start ringtone / ringback based on direction + pre-answer state.
    final remoteRaw = _extractRemoteNumber(call);
    final isPreAnswer = (state.state == CallStateEnum.CALL_INITIATION ||
        state.state == CallStateEnum.PROGRESS);
    if (isPreAnswer && answeredAt == null) {
      if (dir == CallDirection.incoming) {
        RingtonePlayer.instance.playIncoming();
        NotificationService.instance.showIncomingCall(
          name: _extractDisplayName(call)?.isNotEmpty == true
              ? _extractDisplayName(call)!
              : remoteRaw,
          number: remoteRaw.isNotEmpty ? remoteRaw : 'Unknown',
        );
        unawaited(CallKitService.instance.showIncoming(
          callId: callId,
          name: _extractDisplayName(call)?.isNotEmpty == true
              ? _extractDisplayName(call)!
              : remoteRaw,
          number: remoteRaw.isNotEmpty ? remoteRaw : 'Unknown',
        ));
      } else if (state.state == CallStateEnum.PROGRESS) {
        RingtonePlayer.instance.playOutgoingRingback();
      }
    }

    final number = _extractRemoteNumber(call);
    final displayName = _extractDisplayName(call);
    final applyForeground = _shouldApplyAsForeground(key, state);

    if (applyForeground) {
      if (mapped == CallStatus.active ||
          mapped == CallStatus.connecting ||
          mapped == CallStatus.ringing) {
        _foregroundCallId = key;
      }
      _activeCall = CallEntity(
        id: callId,
        number: number,
        displayName: displayName,
        direction: dir,
        status: mapped,
        startedAt: _activeCall?.id == callId
            ? (_activeCall!.startedAt)
            : DateTime.now(),
        answeredAt: answeredAt,
        endedAt: endedAt,
        muted: _muted,
        onHold: mapped == CallStatus.held,
        speakerOn: _speakerOn,
        endReason: endReason ?? _activeCall?.endReason,
        hangupCode: hangupCode ?? _activeCall?.hangupCode,
      );
    } else if (_isHeldLocally(key) &&
        (state.state == CallStateEnum.ENDED ||
            state.state == CallStateEnum.FAILED)) {
      unawaited(ParkedCallStore.instance.remove(key));
      for (final p in List.of(ParkedCallStore.instance.items)) {
        if (CallerLookupService.numbersMatch(p.customerNumber, number)) {
          unawaited(ParkedCallStore.instance.remove(p.id));
        }
      }
    }

    // Persist to history on terminal states.
    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      final ended = applyForeground
          ? _activeCall!
          : CallEntity(
              id: callId,
              number: number,
              displayName: displayName,
              direction: dir,
              status: mapped,
              startedAt: DateTime.now(),
              answeredAt: answeredAt,
              endedAt: endedAt,
              endReason: endReason,
              hangupCode: hangupCode,
            );
      CallHistoryStore.instance.upsert(ended);
      if (dir == CallDirection.outgoing && number.isNotEmpty) {
        unawaited(CallHistoryStore.instance.markFollowUpCalledForNumber(number));
      }
      _calls.remove(key);
      if (_calls.isEmpty) {
        _cleanupMedia();
        unawaited(CallKitService.instance.endAll());
      } else {
        unawaited(CallKitService.instance.endCall(callId));
      }

      void clearActive() {
        if (_activeCall?.id == callId) {
          _activeCall = null;
          if (_foregroundCallId == callId) _foregroundCallId = null;
          notifyListeners();
          unawaited(_tryAutoResumeHeldCall());
        }
      }

      // Unanswered incoming → dismiss UI immediately and log as missed.
      if (_isUnansweredIncomingTerminal(ended)) {
        clearActive();
      } else if (applyForeground) {
        Timer(const Duration(milliseconds: 400), clearActive);
      }
    }

    _syncHeadsetControls();
    notifyListeners();
    unawaited(MobilePresenceService.instance.syncFromSip());
  }

  @override void transportStateChanged(TransportState state) {
    debugPrint('[SIP] transport → ${state.state}');
    // Auto-reconnect ONLY if we were actually registered when the socket dropped.
    // Treating "registering" as a trigger caused a feedback loop: every fresh
    // _startUa() opens a new WS, the old one fires DISCONNECTED, and we
    // immediately schedule another retry — making the UI sit on "Reconnecting…"
    // forever even though the server is reachable.
    if (state.state == TransportStateEnum.DISCONNECTED &&
        _creds != null &&
        _status == SipStatus.registered &&
        !_uaRestarting) {
      _lastError = 'Transport disconnected';
      _scheduleRetry();
    }
  }
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}

  /// Map an Asterisk / Q.850 / SIP hangup cause to a UI [CallStatus],
  /// a human-readable reason, and the originating SIP status code (if any).
  ///
  /// References:
  ///   - Asterisk Hangup Cause Code Mappings (Q.850 ↔ SIP)
  ///   - RFC 3261 (SIP response codes)
  ///
  /// We use this so an outgoing call cancelled by the callee shows "Busy",
  /// "Declined", "No answer", etc. — instead of a generic "Call ended".
  (CallStatus, String?, int?) _mapHangupCause({
    required CallStateEnum state,
    dynamic cause,
    dynamic originator,
    required CallDirection direction,
    required bool answered,
  }) {
    int? code;
    String? phrase;
    String? rawCause;
    try {
      code = cause?.status_code as int?;
    } catch (_) {}
    try {
      phrase = cause?.reason_phrase as String?;
    } catch (_) {}
    try {
      rawCause = cause?.cause?.toString();
    } catch (_) {}

    final originatedLocal = _isLocalOriginator(originator);
    final upper = (rawCause ?? '').toUpperCase();

    // Quick string-based fallbacks (sip_ua emits "BUSY", "REJECTED", "CANCELED"…).
    bool causeContains(String s) => upper.contains(s);

    // Map by SIP response code first — most precise.
    if (code != null) {
      switch (code) {
        case 486:
        case 600:
          return (CallStatus.busy, 'User busy', code);
        case 603:
          return (CallStatus.declined, 'Declined', code);
        case 401:
        case 403:
        case 407:
          return (CallStatus.declined, phrase ?? 'Call rejected', code);
        case 408:
          return (CallStatus.noAnswer, 'No response', code);
        case 480:
          return (CallStatus.noAnswer, 'Temporarily unavailable', code);
        case 487:
          // Request Terminated — usually after a CANCEL.
          if (originatedLocal && !answered) {
            return (CallStatus.canceled, 'Cancelled', code);
          }
          return (CallStatus.noAnswer, 'No answer', code);
        case 404:
        case 485:
        case 604:
          return (CallStatus.unavailable, 'Number not found', code);
        case 410:
          return (CallStatus.unavailable, 'Number changed', code);
        case 484:
          return (CallStatus.unavailable, 'Invalid number', code);
        case 488:
        case 606:
          return (CallStatus.failed, 'Media not acceptable', code);
        case 500:
        case 502:
        case 503:
        case 504:
          return (CallStatus.failed, phrase ?? 'Server error', code);
      }
      if (code >= 400 && code < 700) {
        // Generic 4xx/5xx/6xx fallback.
        return (CallStatus.failed, phrase ?? 'Call failed ($code)', code);
      }
    }

    // No SIP code — fall back to Q.850 / sip_ua cause strings.
    if (causeContains('BUSY')) return (CallStatus.busy, 'User busy', code);
    if (causeContains('REJECT') || causeContains('DECLINE')) {
      return (CallStatus.declined, 'Declined', code);
    }
    if (causeContains('NO_ANSWER') || causeContains('NOANSWER') ||
        causeContains('EXPIRES') || causeContains('REQUEST_TIMEOUT')) {
      return (CallStatus.noAnswer, 'No answer', code);
    }
    if (causeContains('CANCELED') || causeContains('CANCELLED')) {
      if (answered) return (CallStatus.ended, null, code);
      return originatedLocal
          ? (CallStatus.canceled, 'Cancelled', code)
          : (direction == CallDirection.incoming
              ? CallStatus.missed
              : CallStatus.canceled,
             'Cancelled', code);
    }
    if (causeContains('UNAVAILABLE') || causeContains('NOT_FOUND') ||
        causeContains('ADDRESS_INCOMPLETE')) {
      return (CallStatus.unavailable, 'Unavailable', code);
    }
    if (causeContains('CONNECTION_ERROR') ||
        causeContains('NETWORK') ||
        causeContains('TRANSPORT')) {
      return (CallStatus.failed, 'Network error', code);
    }

    // ENDED with no further info → normal clearing.
    if (state == CallStateEnum.ENDED) {
      if (!answered) {
        if (direction == CallDirection.incoming) {
          return (CallStatus.missed, 'Missed call', code);
        }
        return originatedLocal
            ? (CallStatus.canceled, 'Cancelled', code)
            : (CallStatus.noAnswer, 'No answer', code);
      }
      return (CallStatus.ended, null, code);
    }

    // FAILED with no recognizable info.
    if (!answered && direction == CallDirection.incoming) {
      return (CallStatus.missed, 'Missed call', code);
    }
    return (CallStatus.failed, phrase ?? rawCause, code);
  }
}
