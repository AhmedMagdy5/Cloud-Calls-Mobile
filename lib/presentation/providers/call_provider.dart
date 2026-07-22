import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../domain/entities/call_entity.dart';
import '../../features/sip/sip_service.dart';
import 'auth_provider.dart';

final callProvider = ChangeNotifierProvider<CallController>((ref) {
  return CallController(ref.read(sipServiceProvider));
});

class CallController extends ChangeNotifier {
  final SipService sip;
  bool _wakelockOn = false;
  CallController(this.sip) {
    sip.addListener(_forward);
  }
  void _forward() {
    _syncWakelock();
    notifyListeners();
  }

  void _syncWakelock() {
    final live = (sip.activeCall != null && !(sip.activeCall!.status.isTerminal)) ||
        sip.hasHeldCalls;
    if (live && !_wakelockOn) {
      _wakelockOn = true;
      WakelockPlus.enable().catchError((e) => debugPrint('[Wakelock] $e'));
    } else if (!live && _wakelockOn) {
      _wakelockOn = false;
      WakelockPlus.disable().catchError((e) => debugPrint('[Wakelock] $e'));
    }
  }

  CallEntity? get current => sip.activeCall;
  bool get speakerOn => sip.speakerOn;
  String? get accountLabel => sip.credentials?.username;

  Future<void> dial(String number) => sip.makeCall(number);
  void answer() => sip.answer();
  void hangup() => sip.hangup();
  void toggleHold() => current?.onHold == true ? sip.unhold() : sip.hold();
  void toggleMute() => sip.mute(!(current?.muted ?? false));
  Future<void> toggleSpeaker() => sip.setSpeaker(!sip.speakerOn);
  void dtmf(String t) => sip.sendDtmf(t);
  void transfer(String t) => sip.transfer(t);
  void park() => sip.parkCurrentCall();
  Future<void> resumeHeldCall(String id) => sip.resumeHeldCall(id);
  void hangupHeldCall(String id) => sip.hangupHeldCall(id);

  @override
  void dispose() {
    if (_wakelockOn) WakelockPlus.disable();
    sip.removeListener(_forward);
    super.dispose();
  }
}
