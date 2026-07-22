import 'package:flutter/material.dart';
import '../../core/i18n/app_strings.dart';
import '../../domain/entities/contact_tag.dart';

class ContactTagChip extends StatelessWidget {
  final ContactTag tag;
  final bool compact;

  const ContactTagChip({super.key, required this.tag, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final color = tag.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Text(tag.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
          ],
          Icon(tag.icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            tag.label(s),
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ContactTagWrap extends StatelessWidget {
  final List<ContactTag> tags;
  final bool compact;

  const ContactTagWrap({super.key, required this.tags, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in tags) ContactTagChip(tag: t, compact: compact)],
    );
  }
}
