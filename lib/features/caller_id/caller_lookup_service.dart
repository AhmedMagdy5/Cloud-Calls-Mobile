import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/call_history_store.dart';
import '../../data/contacts_store.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/contact_tag.dart';

class CallerInfo {
  final String number;
  final String? displayName;
  final bool isKnownContact;
  final int previousCallsCount;
  final DateTime? lastInteraction;
  final String? lastDisposition;
  final String? lastNote;
  final List<ContactTag> tags;
  final bool isBlocked;
  final bool isVip;

  const CallerInfo({
    required this.number,
    this.displayName,
    this.isKnownContact = false,
    this.previousCallsCount = 0,
    this.lastInteraction,
    this.lastDisposition,
    this.lastNote,
    this.tags = const [],
    this.isBlocked = false,
    this.isVip = false,
  });

  String truncatedNote([int max = 80]) {
    final n = lastNote?.trim();
    if (n == null || n.isEmpty) return '';
    if (n.length <= max) return n;
    return '${n.substring(0, max)}...';
  }
}

/// Local Smart Caller ID — contacts first, then call history.
class CallerLookupService {
  CallerLookupService._();
  static final instance = CallerLookupService._();

  static String normalize(String phone) {
    var s = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('00')) s = s.substring(2);
    return s.replaceAll(RegExp(r'[^0-9+*#]'), '');
  }

  static bool numbersMatch(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    const minSuffix = 8;
    if (na.length >= minSuffix && nb.length >= minSuffix) {
      final shorter = na.length <= nb.length ? na : nb;
      final longer = na.length > nb.length ? na : nb;
      if (longer.endsWith(shorter)) return true;
    }
    return false;
  }

  Future<CallerInfo> lookupNumber(String phoneNumber) async {
    await ContactsStore.instance.load();
    await CallHistoryStore.instance.load();

    final contact = ContactsStore.instance.findByNumber(phoneNumber) ??
        _findContactFuzzy(phoneNumber);

    final history = CallHistoryStore.instance.items
        .where((c) => numbersMatch(c.number, phoneNumber))
        .toList();

    final previousCallsCount = history.length;
    CallEntity? latest;
    if (history.isNotEmpty) {
      history.sort((a, b) {
        final ta = a.endedAt ?? a.startedAt;
        final tb = b.endedAt ?? b.startedAt;
        return tb.compareTo(ta);
      });
      latest = history.first;
    }

    final tags = <ContactTag>[...(contact?.tags ?? const [])];
    final blocked = contact?.blocked == true || tags.contains(ContactTag.blocked);
    if (contact?.blocked == true && !tags.contains(ContactTag.blocked)) {
      tags.add(ContactTag.blocked);
    }

    String? displayName = contact?.name;
    if ((displayName == null || displayName.trim().isEmpty) &&
        latest?.displayName?.isNotEmpty == true) {
      displayName = latest!.displayName;
    }

    final lastInteraction = latest != null
        ? (latest.endedAt ?? latest.answeredAt ?? latest.startedAt)
        : null;

    String? lastDisposition;
    if (latest != null && latest.disposition != CallDisposition.none) {
      lastDisposition = latest.disposition.label;
    }

    final lastNote = latest?.note?.trim().isNotEmpty == true
        ? latest!.note!.trim()
        : null;

    return CallerInfo(
      number: phoneNumber,
      displayName: displayName,
      isKnownContact: contact != null,
      previousCallsCount: previousCallsCount,
      lastInteraction: lastInteraction,
      lastDisposition: lastDisposition,
      lastNote: lastNote,
      tags: tags,
      isBlocked: blocked,
      isVip: tags.contains(ContactTag.vip),
    );
  }

  ContactEntity? _findContactFuzzy(String phoneNumber) {
    for (final c in ContactsStore.instance.items) {
      if (numbersMatch(c.number, phoneNumber)) return c;
    }
    return null;
  }
}

final callerLookupProvider =
    FutureProvider.family<CallerInfo, String>((ref, number) async {
  if (number.trim().isEmpty) {
    return CallerInfo(number: number);
  }
  return CallerLookupService.instance.lookupNumber(number);
});
