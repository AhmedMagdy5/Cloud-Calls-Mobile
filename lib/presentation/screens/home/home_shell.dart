import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../dialer/dialer_screen.dart';
import '../history/history_screen.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/agent_providers.dart';
import '../../providers/call_provider.dart';
import '../../providers/parked_call_provider.dart';
import '../../../data/parked_call_store.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../features/sip/sip_service.dart';


class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _idx = 2;
  final _pages = const [
    HistoryScreen(),
    ContactsScreen(),
    DialerScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tasksAndFollowUpsProvider.future);
      ParkedCallStore.instance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sip = ref.watch(sipServiceProvider);
    ref.watch(parkedCallStoreProvider);
    final s = context.s;
    return AnimatedBuilder(
      animation: sip,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => setState(() => _idx = 3),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.appTitle),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _presenceColor(sip),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _presenceLabel(context, sip),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _presenceColor(sip),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.task_alt),
                tooltip: 'Tasks',
                onPressed: () => context.push('/tasks'),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.push('/profile'),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _ParkedCallsBar(store: ParkedCallStore.instance),
              _OngoingCallBar(sip: sip),
              Expanded(child: _pages[_idx]),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _idx,
            onDestinationSelected: (i) => setState(() => _idx = i),
            destinations: [
              NavigationDestination(icon: const Icon(Icons.history), label: s.tabRecents),
              NavigationDestination(icon: const Icon(Icons.contacts_outlined), label: s.tabContacts),
              NavigationDestination(icon: const Icon(Icons.dialpad_rounded), label: s.tabKeypad),
              NavigationDestination(icon: const Icon(Icons.settings_outlined), label: s.tabSettings),
            ],
          ),
        );
      },
    );
  }


  Color _presenceColor(SipService sip) {
    switch (sip.presence) {
      case PresenceMode.offline:
        return Colors.grey;
      case PresenceMode.dnd:
        return const Color(0xFFEF4444);
      case PresenceMode.online:
        return sip.isRegistered
            ? const Color(0xFF22C55E)
            : const Color(0xFFF59E0B);
    }
  }

  String _presenceLabel(BuildContext context, SipService sip) {
    final s = S.of(context);
    final reason = sip.breakReasonLabel;
    switch (sip.presence) {
      case PresenceMode.offline:
        return reason != null && reason.isNotEmpty
            ? '${s.offline} • $reason'
            : s.offline;
      case PresenceMode.dnd:
        return reason != null && reason.isNotEmpty
            ? '${s.doNotDisturb} • $reason'
            : s.doNotDisturb;
      case PresenceMode.online:
        return sip.isRegistered ? s.online : s.connecting;
    }
  }
}


/// Banner for each call parked on the PBX — tap to retrieve via parking slot.
class _ParkedCallsBar extends ConsumerWidget {
  final ParkedCallStore store;
  const _ParkedCallsBar({required this.store});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
    final parked = store.items;
    if (parked.isEmpty) return const SizedBox.shrink();
    final s = context.s;
    final c = ref.read(callProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in parked)
          Material(
            color: const Color(0xFFF59E0B),
            child: InkWell(
              onTap: () async {
                try {
                  context.push('/call/active');
                  await c.resumeHeldCall(p.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.local_parking, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${s.heldCallOnHold} • ${s.retrievePark}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: s.dismissPark,
                        icon: const Icon(Icons.call_end, color: Colors.white70, size: 20),
                        onPressed: () => c.hangupHeldCall(p.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
      },
    );
  }
}


/// Floating "ongoing call" bar shown when there's an active call
/// but the user has navigated away from the call screen.
class _OngoingCallBar extends StatefulWidget {
  final SipService sip;
  const _OngoingCallBar({required this.sip});
  @override
  State<_OngoingCallBar> createState() => _OngoingCallBarState();
}

class _OngoingCallBarState extends State<_OngoingCallBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.sip.activeCall;
    if (call == null) return const SizedBox.shrink();
    // Hide on the call screens themselves.
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == '/call/active' || loc == '/call/incoming') {
      return const SizedBox.shrink();
    }
    // Only show for live calls.
    if (call.status.isTerminal) {
      return const SizedBox.shrink();
    }

    final started = call.answeredAt ?? call.startedAt;
    final dur = DateTime.now().difference(started);
    final mm = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    final s = context.s;
    final timeText = call.answeredAt != null
        ? '$mm:$ss'
        : (call.status == CallStatus.ringing ? s.ringing : s.connecting);


    return Material(
      color: const Color(0xFF16A34A),
      child: InkWell(
        onTap: () => context.push('/call/active'),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        call.displayName?.isNotEmpty == true
                            ? call.displayName!
                            : call.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${s.tapToReturn}  •  $timeText',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white.withOpacity(0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => widget.sip.hangup(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.call_end,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
