import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/services/storage_service.dart';
import '../domain/entities/call_entity.dart';
import 'follow_up_state_store.dart';

/// Persistent call history (SharedPreferences-backed JSON).
/// Auto-records every call lifecycle event from SipService.
class CallHistoryStore extends ChangeNotifier {
  CallHistoryStore._();
  static final instance = CallHistoryStore._();

  static const _key = 'call_history_v2';
  final List<CallEntity> _items = [];
  bool _loaded = false;

  List<CallEntity> get items => List.unmodifiable(_items);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = StorageService.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .map(_fromJson));
        }
      } catch (e) {
        debugPrint('[History] load error: $e');
      }
    }
    _loaded = true;
  }

  Future<void> load() async {
    await _ensureLoaded();
    notifyListeners();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_items.map(_toJson).toList());
    await StorageService.setString(_key, raw);
  }

  /// Insert or update a call by id (preserves notes/disposition on updates).
  Future<void> upsert(CallEntity call) async {
    await _ensureLoaded();
    final idx = _items.indexWhere((c) => c.id == call.id && call.id.isNotEmpty);
    if (idx >= 0) {
      final prev = _items[idx];
      _items[idx] = call.copyWith(
        note: call.note ?? prev.note,
        disposition: call.disposition == CallDisposition.none
            ? prev.disposition
            : call.disposition,
        followUpAt: call.followUpAt ?? prev.followUpAt,
        followUpCalledAt: call.followUpCalledAt ?? prev.followUpCalledAt,
        followUpActionNote: call.followUpActionNote ?? prev.followUpActionNote,
        followUpCompletedAt: call.followUpCompletedAt ?? prev.followUpCompletedAt,
      );
    } else {
      _items.insert(0, call);
    }
    if (_items.length > 500) _items.removeRange(500, _items.length);
    await _persist();
    notifyListeners();
  }

  /// Update CRM metadata only (after-call sheet).
  Future<void> updateMeta(
    String id, {
    String? note,
    CallDisposition? disposition,
    DateTime? followUpAt,
    DateTime? followUpCalledAt,
    String? followUpActionNote,
    DateTime? followUpCompletedAt,
    bool clearFollowUp = false,
    bool clearFollowUpCalled = false,
    bool clearFollowUpCompleted = false,
  }) async {
    await _ensureLoaded();
    final i = _items.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(
      note: note ?? _items[i].note,
      disposition: disposition ?? _items[i].disposition,
      followUpAt: clearFollowUp ? null : (followUpAt ?? _items[i].followUpAt),
      followUpCalledAt: clearFollowUpCalled
          ? null
          : (followUpCalledAt ?? _items[i].followUpCalledAt),
      followUpActionNote: followUpActionNote ?? _items[i].followUpActionNote,
      followUpCompletedAt: clearFollowUpCompleted
          ? null
          : (followUpCompletedAt ?? _items[i].followUpCompletedAt),
      clearFollowUp: clearFollowUp,
      clearFollowUpCalled: clearFollowUpCalled,
      clearFollowUpCompleted: clearFollowUpCompleted,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    _items.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  // ---------- Stats ----------
  ({int total, int incoming, int outgoing, int missed, Duration talkTime})
      todayStats() {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    int total = 0, inc = 0, out = 0, miss = 0;
    Duration talk = Duration.zero;
    for (final c in _items) {
      if (!isToday(c.startedAt)) continue;
      total++;
      if (c.status == CallStatus.missed) miss++;
      else if (c.direction == CallDirection.incoming) inc++;
      else out++;
      talk += c.duration;
    }
    return (total: total, incoming: inc, outgoing: out, missed: miss, talkTime: talk);
  }

  /// Open follow-ups — still waiting for the agent to call.
  List<CallEntity> activeFollowUps() {
    return _items
        .where((c) =>
            c.followUpAt != null &&
            c.followUpCalledAt == null &&
            c.followUpCompletedAt == null)
        .toList()
      ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
  }

  /// Called or closed follow-ups for the Done tab.
  List<CallEntity> handledFollowUps() {
    return _items
        .where((c) => c.followUpCompletedAt != null || c.followUpCalledAt != null)
        .toList()
      ..sort((a, b) {
        final ad = a.followUpCompletedAt ??
            a.followUpCalledAt ??
            a.followUpAt ??
            a.endedAt ??
            a.startedAt;
        final bd = b.followUpCompletedAt ??
            b.followUpCalledAt ??
            b.followUpAt ??
            b.endedAt ??
            b.startedAt;
        return bd.compareTo(ad);
      });
  }

  /// Upcoming follow-ups only (for history stats badge).
  List<CallEntity> pendingFollowUps() {
    final now = DateTime.now();
    return activeFollowUps().where((c) => c.followUpAt!.isAfter(now)).toList();
  }

  Future<void> markFollowUpCalled(String id) async {
    await updateMeta(id, followUpCalledAt: DateTime.now());
  }

  /// Marks the pending follow-up for [number] as called (by phone, then call id).
  Future<String?> markFollowUpCalledForNumber(String number, {String? callId}) async {
    await _ensureLoaded();
    final target = FollowUpStateStore.normalizePhone(number);
    if (target.isEmpty && (callId == null || callId.isEmpty)) return null;

    String? matchedId;
    for (final c in activeFollowUps()) {
      if (c.followUpCalledAt != null) continue;
      final samePhone = target.isNotEmpty &&
          FollowUpStateStore.normalizePhone(c.number) == target;
      final sameId = callId != null && callId.isNotEmpty && c.id == callId;
      if (samePhone || sameId) {
        matchedId = c.id;
        await updateMeta(c.id, followUpCalledAt: DateTime.now());
        break;
      }
    }

    if (matchedId == null &&
        callId != null &&
        callId.isNotEmpty &&
        _items.any((c) => c.id == callId && c.followUpAt != null)) {
      matchedId = callId;
      await updateMeta(callId, followUpCalledAt: DateTime.now());
    }

    if (target.isNotEmpty) {
      await FollowUpStateStore.instance.markCalled(number, callId: matchedId ?? callId);
    }
    return matchedId ?? callId;
  }

  Future<void> completeFollowUp(String id, {String? actionNote, String? number}) async {
    await _ensureLoaded();
    final i = _items.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final prev = _items[i];
    final mergedNote = actionNote != null && actionNote.isNotEmpty
        ? [
            if (prev.note != null && prev.note!.isNotEmpty) prev.note,
            'Follow-up closed: $actionNote',
          ].join('\n')
        : prev.note;
    _items[i] = prev.copyWith(
      note: mergedNote,
      followUpActionNote: actionNote?.isNotEmpty == true ? actionNote : prev.followUpActionNote,
      followUpCompletedAt: DateTime.now(),
      clearFollowUp: true,
      clearFollowUpCalled: false,
    );
    await _persist();
    notifyListeners();
    await FollowUpStateStore.instance.clear(number ?? prev.number);
  }

  Map<String, dynamic> _toJson(CallEntity c) => {
        'id': c.id,
        'number': c.number,
        'displayName': c.displayName,
        'direction': c.direction.name,
        'status': c.status.name,
        'startedAt': c.startedAt.toIso8601String(),
        'answeredAt': c.answeredAt?.toIso8601String(),
        'endedAt': c.endedAt?.toIso8601String(),
        'note': c.note,
        'disposition': c.disposition.name,
        'followUpAt': c.followUpAt?.toIso8601String(),
        'followUpCalledAt': c.followUpCalledAt?.toIso8601String(),
        'followUpActionNote': c.followUpActionNote,
        'followUpCompletedAt': c.followUpCompletedAt?.toIso8601String(),
        'endReason': c.endReason,
        'hangupCode': c.hangupCode,
      };

  CallEntity _fromJson(Map<String, dynamic> j) => CallEntity(
        id: j['id'] ?? '',
        number: j['number'] ?? '',
        displayName: j['displayName'],
        direction: CallDirection.values.firstWhere(
            (e) => e.name == j['direction'],
            orElse: () => CallDirection.outgoing),
        status: CallStatus.values.firstWhere((e) => e.name == j['status'],
            orElse: () => CallStatus.ended),
        startedAt:
            DateTime.tryParse(j['startedAt'] ?? '') ?? DateTime.now(),
        answeredAt: j['answeredAt'] == null
            ? null
            : DateTime.tryParse(j['answeredAt']),
        endedAt:
            j['endedAt'] == null ? null : DateTime.tryParse(j['endedAt']),
        note: j['note'],
        disposition: CallDisposition.values.firstWhere(
            (e) => e.name == j['disposition'],
            orElse: () => CallDisposition.none),
        followUpAt: j['followUpAt'] == null
            ? null
            : DateTime.tryParse(j['followUpAt']),
        followUpCalledAt: j['followUpCalledAt'] == null
            ? null
            : DateTime.tryParse(j['followUpCalledAt']),
        followUpActionNote: j['followUpActionNote'] as String?,
        followUpCompletedAt: j['followUpCompletedAt'] == null
            ? null
            : DateTime.tryParse(j['followUpCompletedAt']),
        endReason: j['endReason'] as String?,
        hangupCode: (j['hangupCode'] as num?)?.toInt(),
      );
}
