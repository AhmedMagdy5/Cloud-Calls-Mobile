import 'dart:convert';

import '../core/services/storage_service.dart';

/// Phone-keyed follow-up callback state — survives call-id changes between sessions.
class FollowUpStateStore {
  FollowUpStateStore._();
  static final instance = FollowUpStateStore._();

  static const _key = 'follow_up_called_v1';

  static String normalizePhone(String n) => n.replaceAll(RegExp(r'\D'), '');

  Future<DateTime?> calledAtFor(String number) async {
    final phone = normalizePhone(number);
    if (phone.isEmpty) return null;
    return calledAtByPhone()[phone];
  }

  /// One storage read for building task lists.
  Map<String, DateTime> calledAtByPhone() {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final out = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final phone = entry.key.toString();
        final value = entry.value;
        DateTime? at;
        if (value is Map) {
          at = DateTime.tryParse(value['calledAt']?.toString() ?? '');
        } else {
          at = DateTime.tryParse(value.toString());
        }
        if (at != null) out[phone] = at;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> markCalled(String number, {String? callId}) async {
    final phone = normalizePhone(number);
    if (phone.isEmpty) return;
    final map = await _load();
    map[phone] = {
      'calledAt': DateTime.now().toIso8601String(),
      if (callId != null && callId.isNotEmpty) 'callId': callId,
    };
    await _save(map);
  }

  Future<void> clear(String number) async {
    final phone = normalizePhone(number);
    if (phone.isEmpty) return;
    final map = await _load();
    if (map.remove(phone) != null) await _save(map);
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = StorageService.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> map) async {
    await StorageService.setString(_key, jsonEncode(map));
  }
}
