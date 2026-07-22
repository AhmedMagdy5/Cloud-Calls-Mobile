import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/call_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../features/sip/sip_service.dart';
import '../../../data/contacts_store.dart';
import '../../../features/share/share_intent_handler.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../domain/entities/break_reason.dart';
import '../../widgets/reason_picker_sheet.dart';


/// Production softphone dialer — iOS-style rounded keypad with SIP account card.
class DialerScreen extends ConsumerStatefulWidget {
  const DialerScreen({super.key});
  @override
  ConsumerState<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends ConsumerState<DialerScreen> {
  String _number = '';

  void _append(String d) {
    HapticFeedback.selectionClick();
    setState(() => _number += d);
  }

  void _back() {
    if (_number.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _longBack() {
    HapticFeedback.mediumImpact();
    setState(() => _number = '');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPrefill());
  }

  void _applyPrefill() {
    final prefill = ref.read(dialerPrefillProvider);
    if (prefill != null && prefill.isNotEmpty && mounted) {
      setState(() => _number = prefill);
      ref.read(dialerPrefillProvider.notifier).state = null;
    }
  }

  Future<void> _call() async {
    if (_number.isEmpty) return;
    final sip = ref.read(sipServiceProvider);
    if (sip.presence == PresenceMode.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.youAreOffline)),
      );
      return;
    }
    HapticFeedback.mediumImpact();

    context.push('/call/active');
    try {
      await ref.read(callProvider).dial(_number);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _addContact() async {
    HapticFeedback.selectionClick();
    if (_number.isEmpty) {
      // No number typed — go to contacts screen.
      context.push('/contacts');
      return;
    }
    final nameCtrl = TextEditingController();
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.addNewContact),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.name,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: InputDecoration(
                labelText: s.number,
                prefixIcon: const Icon(Icons.call),
              ),
              child: Text(_number),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.save)),
        ],
      ),
    );
    if (ok == true) {
      final name = nameCtrl.text.trim().isEmpty ? _number : nameCtrl.text.trim();
      await ContactsStore.instance.add(name: name, number: _number);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.savedAs(name))),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(dialerPrefillProvider, (_, next) {
      if (next != null && next.isNotEmpty && mounted) {
        setState(() => _number = next);
        ref.read(dialerPrefillProvider.notifier).state = null;
      }
    });
    final sip = ref.watch(sipServiceProvider);
    return AnimatedBuilder(
      animation: sip,
      builder: (_, __) {
        return SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            // Reserve heights for fixed sections.
            const sipCardH = 68.0;
            const numberH = 60.0;
            const actionsH = 76.0;
            // Spacings between sections.
            final gapTop = 4.0;
            final gap1 = h < 640 ? 6.0 : 10.0;
            final gap2 = h < 640 ? 10.0 : 18.0;
            final gap3 = h < 640 ? 10.0 : 18.0;
            final bottomPad = h < 640 ? 6.0 : 12.0;

            // Compute grid (4 rows x 3 cols) area.
            final availableForGrid = h -
                (gapTop + sipCardH + gap1 + numberH + gap2 + actionsH + gap3 + bottomPad);
            // Use most of the screen width — like native iOS dialer.
            final sidePad = w < 360 ? 16.0 : 24.0;
            final keypadWidth = (w - sidePad * 2).clamp(260.0, 400.0);

            // Button size: gap ≈ button * 0.42 horizontally (matches reference).
            // total width = 3*btn + 2*gap = 3.84*btn
            final byWidth = keypadWidth / 3.84;
            // Vertical: gap ≈ 0.22*btn → 4*btn + 3*0.22*btn = 4.66*btn
            final byHeight = availableForGrid / 4.66;
            final btnSize = byWidth < byHeight ? byWidth : byHeight;
            final clampedBtn = btnSize.clamp(58.0, 84.0);
            final hSpacing = clampedBtn * 0.42;
            final vSpacing = clampedBtn * 0.22;
            final gridHeight = clampedBtn * 4 + vSpacing * 3;
            final actualKeypadW = clampedBtn * 3 + hSpacing * 2;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (w - actualKeypadW) / 2,
              ),
              child: Column(
                children: [
                  SizedBox(height: gapTop),
                  SizedBox(height: sipCardH, child: _SipAccountCard(sip: sip)),
                  SizedBox(height: gap1),
                  _NumberField(
                    number: _number,
                    onAddContact: _addContact,
                  ),
                  SizedBox(height: gap2),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SizedBox(
                    width: actualKeypadW,
                    height: gridHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int r = 0; r < 4; r++) ...[
                          if (r > 0) SizedBox(height: vSpacing),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (int col = 0; col < 3; col++) ...[
                                if (col > 0) SizedBox(width: hSpacing),
                                _Key(
                                  label: const [
                                    ['1','2','3'],
                                    ['4','5','6'],
                                    ['7','8','9'],
                                    ['*','0','#'],
                                  ][r][col],
                                  sub: _sub(const [
                                    ['1','2','3'],
                                    ['4','5','6'],
                                    ['7','8','9'],
                                    ['*','0','#'],
                                  ][r][col]),
                                  size: clampedBtn,
                                  onTap: () => _append(const [
                                    ['1','2','3'],
                                    ['4','5','6'],
                                    ['7','8','9'],
                                    ['*','0','#'],
                                  ][r][col]),
                                  onLongPress: (r == 3 && col == 1)
                                      ? () => _append('+')
                                      : null,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                  SizedBox(height: gap3),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SizedBox(
                    height: actionsH,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CircleIconButton(
                          icon: Icons.dialpad_rounded,
                          onTap: () {},
                        ),
                        _CallButton(onTap: _call),
                        // Backspace (moved here from the number field)
                        Opacity(
                          opacity: _number.isEmpty ? 0.35 : 1.0,
                          child: _CircleIconButton(
                            icon: Icons.backspace_outlined,
                            onTap: _back,
                            onLongPress: _longBack,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  SizedBox(height: bottomPad),

                ],
              ),
            );
          }),
        );
      },
    );
  }

  String? _sub(String k) => switch (k) {
        '2' => 'ABC', '3' => 'DEF', '4' => 'GHI', '5' => 'JKL',
        '6' => 'MNO', '7' => 'PQRS', '8' => 'TUV', '9' => 'WXYZ',
        '0' => '+', _ => null,
      };
}

// ─────────────────────────────────────────────────────────────
// SIP Account Card
// ─────────────────────────────────────────────────────────────
class _SipAccountCard extends StatelessWidget {
  final SipService sip;
  const _SipAccountCard({required this.sip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final creds = sip.credentials;
    final color = _presenceColor(sip);
    final label = _presenceLabel(context, sip);
    final s = context.s;


    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/settings/sip'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.call_outlined,
                    size: 19, color: cs.onSurface.withOpacity(0.8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.sipAccount,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      creds != null && creds.username.isNotEmpty
                          ? '${creds.username}@${creds.server}'
                          : s.notConfigured,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.6)),
                    ),

                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showPresenceSheet(context, sip),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    Icon(Icons.arrow_drop_down, size: 16, color: color),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _presenceColor(SipService sip) {
    switch (sip.presence) {
      case PresenceMode.offline: return Colors.grey;
      case PresenceMode.dnd: return const Color(0xFFEF4444);
      case PresenceMode.online:
        return sip.isRegistered ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    }
  }

  String _presenceLabel(BuildContext context, SipService sip) {
    final s = S.of(context);
    switch (sip.presence) {
      case PresenceMode.offline: return s.offline;
      case PresenceMode.dnd: return s.dnd;
      case PresenceMode.online: return sip.isRegistered ? s.online : s.connecting;
    }
  }

  void _showPresenceSheet(BuildContext context, SipService sip) {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(PresenceMode m, IconData icon, Color color, String title, String subtitle) {
          final selected = sip.presence == m;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: selected ? Icon(Icons.check, color: color) : null,
            onTap: () async {
              Navigator.pop(ctx);
              if (m == PresenceMode.online) {
                await sip.setPresence(m);
                return;
              }
              final title = m == PresenceMode.offline
                  ? S.of(context).goingOffline
                  : S.of(context).goingDnd;
              final res = await showReasonPickerSheet(context, title: title);
              if (res == null) return;
              await sip.setPresence(
                m,
                reason: res.reason.apiValue,
                customReason: res.customReason,
              );
            },
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(s.status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              tile(PresenceMode.online, Icons.check_circle, const Color(0xFF22C55E),
                  s.online, s.presenceOnlineSub),
              tile(PresenceMode.dnd, Icons.do_not_disturb_on, const Color(0xFFEF4444),
                  s.doNotDisturb, s.presenceDndSub),
              tile(PresenceMode.offline, Icons.cloud_off, Colors.grey,
                  s.offline, s.presenceOfflineSub),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Number Field
// ─────────────────────────────────────────────────────────────
class _NumberField extends StatelessWidget {
  final String number;
  final VoidCallback onAddContact;
  const _NumberField({
    required this.number,
    required this.onAddContact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.only(start: 18, end: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    number.isEmpty ? context.s.enterNumber : number,
                    style: TextStyle(
                      fontSize: number.isEmpty ? 18 : 28,
                      fontWeight: FontWeight.w500,
                      letterSpacing: number.isEmpty ? 0 : 1.2,
                      color: number.isEmpty
                          ? cs.onSurface.withOpacity(0.45)
                          : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onAddContact,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.person_add_alt_1_outlined,
                  size: 22, color: cs.onSurface.withOpacity(0.75)),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Call button
// ─────────────────────────────────────────────────────────────
class _CallButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CallButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF22C55E),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: const Color(0xFF22C55E).withOpacity(0.6),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 76,
          height: 76,
          child: Icon(Icons.call, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small round secondary icon button
// ─────────────────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _CircleIconButton({required this.icon, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, size: 22, color: cs.onSurface.withOpacity(0.85)),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Single key
// ─────────────────────────────────────────────────────────────
class _Key extends StatefulWidget {
  final String label;
  final String? sub;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Key({
    required this.label,
    required this.size,
    required this.onTap,
    this.sub,
    this.onLongPress,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 80),
          scale: _pressed ? 0.92 : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.size * 0.40,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                    height: 1.0,
                  ),
                ),
                if (widget.sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      widget.sub!,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.55),
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
