import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/call_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/agent_providers.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/caller_info_card.dart';
import '../../../data/call_history_store.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../features/caller_id/caller_lookup_service.dart';
import '../../../core/i18n/app_strings.dart';
import 'post_call_sheet.dart';


class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});
  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  Timer? _ticker;
  Timer? _initialTimeout;
  bool _keypadOpen = false;
  String _dtmfBuffer = '';
  bool _autoPopped = false;
  bool _everSawCall = false;
  CallEntity? _lastSeenCall;
  bool _postCallShown = false;
  final _transferCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _initialTimeout = Timer(const Duration(seconds: 8), () {
      if (!_everSawCall) _pop();
    });
  }

  Future<void> _showTransferDialog(CallController c) async {
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer call'),
        content: TextField(
          controller: _transferCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Extension or number',
            prefixIcon: Icon(Icons.phone_forwarded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _transferCtrl.text.trim()),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (target != null && target.isNotEmpty) {
      c.transfer(target);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transferring to $target')),
        );
      }
    }
    _transferCtrl.clear();
  }

  Future<void> _parkCall(CallController c) async {
    final call = c.current;
    if (call == null || call.answeredAt == null) return;
    final s = context.s;
    final name = call.displayName?.isNotEmpty == true
        ? call.displayName!
        : call.number;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.parkCallTitle),
        content: Text(s.parkCallBody(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.park)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      c.park();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.heldCallSaved(name))),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _initialTimeout?.cancel();
    _transferCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _pop() {
    if (!mounted || _autoPopped) return;
    _autoPopped = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _showPostCallThenPop() async {
    if (_postCallShown) return;
    if (ref.read(sipServiceProvider).hasHeldCalls) {
      _postCallShown = true;
      _pop();
      return;
    }
    _postCallShown = true;
    final call = _lastSeenCall;
    // Only prompt for substantive outcomes — skip pure dial-failures with no answer attempt.
    final eligible = call != null && call.status.isTerminal;
    if (eligible && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (_) => PostCallSheet(call: call),
      );
      // Make sure history reflects updated metadata.
      await CallHistoryStore.instance.load();
    }
    _pop();
  }


  @override
  Widget build(BuildContext context) {
    final c = ref.watch(callProvider);
    final call = c.current;

    if (call != null) {
      _everSawCall = true;
      _lastSeenCall = call;
    }

    // Only auto-close once we've actually seen a call AND it has terminated.
    if (_everSawCall && call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPostCallThenPop());
    } else if (call != null && call.status.isTerminal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), _showPostCallThenPop);
      });
    }


    final name = call?.displayName?.isNotEmpty == true
        ? call!.displayName!
        : (call?.number.isNotEmpty == true ? call!.number : '—');
    final number = call?.number ?? '';
    final showNumberLine =
        call?.displayName != null && call!.displayName!.isNotEmpty;

    final customer = number.isNotEmpty
        ? ref.watch(customerLookupProvider(number))
        : const AsyncValue.data(null);

    final callerInfo = number.isNotEmpty
        ? ref.watch(callerLookupProvider(number))
        : const AsyncValue.data(CallerInfo(number: ''));

    final sip = ref.watch(sipServiceProvider);
    final s = context.s;

    return AnimatedBuilder(
      animation: sip,
      builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(children: [
          // Top bar: minimize button to return home without ending the call.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 30),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              const Spacer(),
              if (sip.headsetConnected)
                Tooltip(
                  message: s.headsetConnected,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('🎧', style: TextStyle(fontSize: 18)),
                  ),
                ),
              if (c.accountLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'via ${c.accountLabel}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ),
              const Spacer(),
              const SizedBox(width: 48),
            ]),
          ),
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white.withOpacity(0.12),
            child: const Icon(Icons.person, size: 66, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showNumberLine) ...[
            const SizedBox(height: 4),
            Text(number,
                style:
                    TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          ],
          const SizedBox(height: 10),
          _StatusPill(status: call?.status),
          if (call?.status == CallStatus.active ||
              call?.status == CallStatus.held) ...[
            const SizedBox(height: 8),
            Text(
              _fmt(call!.duration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          callerInfo.when(
            data: (info) => CollapsibleCallerInfoCard(info: info),
            loading: () => const SizedBox(height: 8),
            error: (_, __) => const SizedBox.shrink(),
          ),
          customer.when(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: CustomerCard(customer: c),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (_keypadOpen && _dtmfBuffer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_dtmfBuffer,
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
            ),
          const Spacer(),
          if (_keypadOpen)
            _InCallKeypad(onTap: (k) {
              c.dtmf(k);
              setState(() => _dtmfBuffer += k);
            })
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 14,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: [
                  _A(
                    icon: call?.muted == true ? Icons.mic_off : Icons.mic,
                    label: 'Mute',
                    active: call?.muted == true,
                    onTap: c.toggleMute,
                  ),
                  _A(
                    icon: Icons.dialpad,
                    label: 'Keypad',
                    onTap: () => setState(() => _keypadOpen = true),
                  ),
                  _A(
                    icon: c.speakerOn ? Icons.volume_up : Icons.volume_down,
                    label: 'Speaker',
                    active: c.speakerOn,
                    onTap: () => c.toggleSpeaker(),
                  ),
                  _A(
                    icon: Icons.pause,
                    label: 'Hold',
                    active: call?.onHold == true,
                    onTap: c.toggleHold,
                  ),
                  _A(
                    icon: Icons.phone_forwarded,
                    label: 'Transfer',
                    onTap: () => _showTransferDialog(c),
                  ),
                  if (call?.answeredAt != null &&
                      (call?.status == CallStatus.active ||
                          call?.status == CallStatus.held))
                    _A(
                      icon: Icons.local_parking_outlined,
                      label: s.park,
                      onTap: () => _parkCall(c),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          if (_keypadOpen)
            TextButton(
              onPressed: () => setState(() {
                _keypadOpen = false;
                _dtmfBuffer = '';
              }),
              child: const Text('Hide keypad',
                  style: TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () { c.hangup(); /* stay on screen — build effect will show PostCallSheet on ENDED */ },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 28),
        ]),
      ),
    ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final CallStatus? status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CallStatus.connecting => ('Dialing…', Colors.amber),
      CallStatus.ringing => ('Ringing…', Colors.amber),
      CallStatus.active => ('Connected', Colors.greenAccent),
      CallStatus.held => ('On hold', Colors.orangeAccent),
      CallStatus.ended => ('Call ended', Colors.white70),
      CallStatus.failed => ('Call failed', Colors.redAccent),
      CallStatus.missed => ('Missed', Colors.redAccent),
      CallStatus.busy => ('User busy', Colors.orangeAccent),
      CallStatus.declined => ('Declined', Colors.redAccent),
      CallStatus.noAnswer => ('No answer', Colors.white70),
      CallStatus.unavailable => ('Unavailable', Colors.redAccent),
      CallStatus.canceled => ('Cancelled', Colors.white70),
      _ => ('—', Colors.white54),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}

class _InCallKeypad extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _InCallKeypad({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 18,
        children: [
          for (final k in const ['1','2','3','4','5','6','7','8','9','*','0','#'])
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onTap(k),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                ),
                child: Center(
                  child: Text(k,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _A extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _A({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(children: [
        Material(
          color: active ? Colors.white : Colors.white.withOpacity(0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon,
                  color: active ? const Color(0xFF0F172A) : Colors.white,
                  size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}
