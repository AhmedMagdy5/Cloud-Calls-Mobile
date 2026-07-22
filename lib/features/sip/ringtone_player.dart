import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Plays ringtone (incoming) and ringback (outgoing) tones during call setup.
/// One instance — only one tone plays at a time.
class RingtonePlayer {
  RingtonePlayer._();
  static final instance = RingtonePlayer._();

  final AudioPlayer _player = AudioPlayer(playerId: 'awfar_ringtone');
  bool _isPlaying = false;
  String? _current;

  Future<void> _start(String asset, {required bool isRingtone}) async {
    if (_isPlaying && _current == asset) return;
    await stop();
    _current = asset;
    _isPlaying = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // For incoming ringtone: route through the ALARM stream so the tone is
      // LOUD regardless of the system ringer/notification volume (and ignores
      // silent/vibrate mode). For outgoing ringback: keep it as in-call
      // signalling so it follows earpiece/speaker routing.
      await _player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: isRingtone,
          audioMode: isRingtone
              ? AndroidAudioMode.normal
              : AndroidAudioMode.inCommunication,
          stayAwake: true,
          contentType: isRingtone
              ? AndroidContentType.music
              : AndroidContentType.sonification,
          usageType: isRingtone
              ? AndroidUsageType.alarm
              : AndroidUsageType.voiceCommunicationSignalling,
          audioFocus: isRingtone
              ? AndroidAudioFocus.gain
              : AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: isRingtone
              ? AVAudioSessionCategory.playback
              : AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));
      await _player.setVolume(1.0);
      await _player.play(AssetSource(asset), volume: 1.0);
      // Force max volume after playback starts (some devices reset on play).
      await _player.setVolume(1.0);
      if (isRingtone) {
        // Vibrate pattern for incoming ring (in addition to loud tone).
        final has = await Vibration.hasVibrator() ?? false;
        if (has) {
          Vibration.vibrate(
            pattern: [0, 1000, 1000, 1000, 1000],
            repeat: 0,
            intensities: [0, 255, 0, 255, 0],
          );
        }
      }
    } catch (e) {
      debugPrint('[Ringtone] start failed: $e');
    }
  }

  Future<void> playIncoming() => _start('sounds/ringtone.mp3', isRingtone: true);
  Future<void> playOutgoingRingback() =>
      _start('sounds/ringback.mp3', isRingtone: false);

  Future<void> stop() async {
    _current = null;
    if (!_isPlaying) return;
    _isPlaying = false;
    try { await _player.stop(); } catch (_) {}
    try { Vibration.cancel(); } catch (_) {}
  }
}
