import 'package:flutter/material.dart';
import '../../core/i18n/app_strings.dart';

enum ContactTag { vip, lead, customer, blocked, complaint, custom }

extension ContactTagX on ContactTag {
  Color get color => switch (this) {
        ContactTag.vip => const Color(0xFFD4AF37),
        ContactTag.lead => const Color(0xFF3B82F6),
        ContactTag.customer => const Color(0xFF22C55E),
        ContactTag.blocked => const Color(0xFFEF4444),
        ContactTag.complaint => const Color(0xFFF97316),
        ContactTag.custom => const Color(0xFF94A3B8),
      };

  IconData get icon => switch (this) {
        ContactTag.vip => Icons.star_rounded,
        ContactTag.lead => Icons.track_changes_rounded,
        ContactTag.customer => Icons.check_circle_rounded,
        ContactTag.blocked => Icons.block_rounded,
        ContactTag.complaint => Icons.warning_amber_rounded,
        ContactTag.custom => Icons.label_rounded,
      };

  String get emoji => switch (this) {
        ContactTag.vip => '⭐',
        ContactTag.lead => '🎯',
        ContactTag.customer => '✅',
        ContactTag.blocked => '🚫',
        ContactTag.complaint => '⚠️',
        ContactTag.custom => '🏷️',
      };

  String label(S s) => switch (this) {
        ContactTag.vip => s.tagVip,
        ContactTag.lead => s.tagLead,
        ContactTag.customer => s.tagCustomer,
        ContactTag.blocked => s.tagBlocked,
        ContactTag.complaint => s.tagComplaint,
        ContactTag.custom => s.tagCustom,
      };

  static ContactTag? tryParse(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    for (final t in ContactTag.values) {
      if (t.name == key) return t;
    }
    const legacy = {
      'vip': ContactTag.vip,
      'lead': ContactTag.lead,
      'client': ContactTag.customer,
      'customer': ContactTag.customer,
      'blocked': ContactTag.blocked,
      'block': ContactTag.blocked,
      'complaint': ContactTag.complaint,
      'custom': ContactTag.custom,
    };
    return legacy[key];
  }

  static List<ContactTag> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ContactTag>[];
    for (final item in raw) {
      final tag = tryParse(item.toString());
      if (tag != null && !out.contains(tag)) out.add(tag);
    }
    return out;
  }
}
