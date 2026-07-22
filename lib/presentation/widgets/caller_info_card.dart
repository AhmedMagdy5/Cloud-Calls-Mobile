import 'package:flutter/material.dart';
import '../../core/i18n/app_strings.dart';
import '../../features/caller_id/caller_lookup_service.dart';
import 'contact_tag_chip.dart';

class CallerInfoCard extends StatelessWidget {
  final CallerInfo info;
  final bool dark;

  const CallerInfoCard({super.key, required this.info, this.dark = true});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fg = dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final muted = dark ? Colors.white.withOpacity(0.65) : Theme.of(context).colorScheme.onSurfaceVariant;
    final cardBg = dark ? Colors.white.withOpacity(0.08) : Theme.of(context).colorScheme.surfaceContainerHighest;

    final hasContent = info.tags.isNotEmpty ||
        info.previousCallsCount > 0 ||
        info.lastInteraction != null ||
        (info.lastDisposition?.isNotEmpty == true) ||
        (info.lastNote?.isNotEmpty == true);

    if (!hasContent && !info.isBlocked) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: info.isBlocked
            ? Border.all(color: Colors.redAccent.withOpacity(0.8), width: 1.5)
            : info.isVip
                ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.7), width: 1.5)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.isBlocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.block, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.callerBlockedWarning,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (info.tags.isNotEmpty) ...[
            ContactTagWrap(tags: info.tags, compact: true),
            const SizedBox(height: 10),
          ],
          if (info.previousCallsCount > 0)
            _Line(
              icon: '📞',
              text: s.callerPreviousCalls(info.previousCallsCount),
              color: fg,
              muted: muted,
            ),
          if (info.lastInteraction != null) ...[
            const SizedBox(height: 6),
            _Line(
              icon: '🕒',
              text: s.callerLastContact(_relativeTime(context, info.lastInteraction!)),
              color: fg,
              muted: muted,
            ),
          ],
          if (info.lastDisposition?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _Line(
              icon: '🏷️',
              text: s.callerLastDisposition(info.lastDisposition!),
              color: fg,
              muted: muted,
            ),
          ],
          if (info.truncatedNote().isNotEmpty) ...[
            const SizedBox(height: 6),
            _Line(
              icon: '📝',
              text: s.callerLastNote(info.truncatedNote()),
              color: fg,
              muted: muted,
            ),
          ],
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final s = context.s;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return s.relativeJustNow;
    if (diff.inMinutes < 60) return s.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.relativeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return s.relativeDaysAgo(diff.inDays);
    if (diff.inDays < 30) return s.relativeWeeksAgo((diff.inDays / 7).floor());
    if (diff.inDays < 365) return s.relativeMonthsAgo((diff.inDays / 30).floor());
    return s.relativeYearsAgo((diff.inDays / 365).floor());
  }
}

class _Line extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;
  final Color muted;

  const _Line({
    required this.icon,
    required this.text,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13, height: 1.35)),
        ),
      ],
    );
  }
}

/// Collapsible caller info for the active call screen.
class CollapsibleCallerInfoCard extends StatefulWidget {
  final CallerInfo info;

  const CollapsibleCallerInfoCard({super.key, required this.info});

  @override
  State<CollapsibleCallerInfoCard> createState() => _CollapsibleCallerInfoCardState();
}

class _CollapsibleCallerInfoCardState extends State<CollapsibleCallerInfoCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.callerInfoTitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CallerInfoCard(info: widget.info),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
