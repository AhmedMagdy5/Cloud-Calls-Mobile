import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bluetooth / wired headset media-button controls during calls.
class HeadsetControls {
  HeadsetControls._();
  static final instance = HeadsetControls._();

  static const _events = EventChannel('com.awfar.cloudcalls/headset_events');

  StreamSubscription<dynamic>? _hookSub;
  StreamSubscription<void>? _devicesSub;
  AudioSession? _session;

  bool bluetoothConnected = false;
  bool _attached = false;
  bool _incomingRinging = false;

  VoidCallback? _onAnswer;
  VoidCallback? _onHangup;
  VoidCallback? _onReject;
  void Function()? _onBluetoothConnected;
  void Function()? onDeviceChange;

  Future<void> init() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      _devicesSub = _session!.devicesChangedEventStream.listen((_) {
        _refreshBluetoothState();
      });
      await _refreshBluetoothState();
    } catch (e) {
      debugPrint('[Headset] init error: $e');
    }
  }

  Future<void> _refreshBluetoothState() async {
    try {
      final session = _session ?? await AudioSession.instance;
      final outputs = await session.getDevices(includeInputs: false);
      final bt = outputs.any((d) =>
          d.type == AudioDeviceType.bluetoothSco ||
          d.type == AudioDeviceType.bluetoothA2dp ||
          d.type == AudioDeviceType.bluetoothLe);
      if (bt != bluetoothConnected) {
        bluetoothConnected = bt;
        onDeviceChange?.call();
        if (bt && _attached) _onBluetoothConnected?.call();
      }
    } catch (e) {
      debugPrint('[Headset] device refresh error: $e');
    }
  }

  Future<void> ensureActiveForCall() async {
    await init();
    try {
      await _session?.setActive(true);
    } catch (e) {
      debugPrint('[Headset] activate session error: $e');
    }
  }

  void attach({
    required bool isIncomingRinging,
    required VoidCallback onAnswer,
    required VoidCallback onHangup,
    required VoidCallback onReject,
    void Function()? onBluetoothConnected,
  }) {
    _attached = true;
    _incomingRinging = isIncomingRinging;
    _onAnswer = onAnswer;
    _onHangup = onHangup;
    _onReject = onReject;
    _onBluetoothConnected = onBluetoothConnected;

    _hookSub ??= _events.receiveBroadcastStream().listen((event) {
      final type = event?.toString() ?? 'short';
      if (!_attached) return;
      if (type == 'long') {
        if (_incomingRinging) {
          _onReject?.call();
        } else {
          _onHangup?.call();
        }
      } else {
        if (_incomingRinging) {
          _onAnswer?.call();
        } else {
          _onHangup?.call();
        }
      }
    });

    unawaited(_session?.setActive(true));
    unawaited(_refreshBluetoothState());
    if (bluetoothConnected) onBluetoothConnected?.call();
  }

  void updateIncomingRinging(bool ringing) {
    _incomingRinging = ringing;
  }

  void detach() {
    _attached = false;
    _incomingRinging = false;
    _onAnswer = null;
    _onHangup = null;
    _onReject = null;
    _onBluetoothConnected = null;
  }

  void dispose() {
    detach();
    _hookSub?.cancel();
    _hookSub = null;
    _devicesSub?.cancel();
    _devicesSub = null;
  }
}
