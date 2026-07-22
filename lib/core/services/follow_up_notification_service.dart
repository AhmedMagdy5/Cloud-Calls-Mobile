import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_config.dart';
import '../services/storage_service.dart';
import '../../data/call_history_store.dart';
import '../../domain/entities/call_entity.dart';

class _FollowUpJob {
  final DateTime dueAt;
  final bool notified;

  const _FollowUpJob({required this.dueAt, this.notified = false});

  Map<String, dynamic> toJson() => {
        'dueAt': dueAt.toIso8601String(),
        'notified': notified,
      };

  factory _FollowUpJob.fromJson(Map<String, dynamic> j) => _FollowUpJob(
        dueAt: DateTime.tryParse(j['dueAt']?.toString() ?? '') ?? DateTime.now(),
        notified: j['notified'] == true,
      );

  _FollowUpJob copyWith({DateTime? dueAt, bool? notified}) => _FollowUpJob(
        dueAt: dueAt ?? this.dueAt,
        notified: notified ?? this.notified,
      );
}

/// Reminds agents once, [AppConfig.followUpReminderMinutes] before scheduled follow-ups.
class FollowUpNotificationService {
  FollowUpNotificationService._();
  static final instance = FollowUpNotificationService._();

  static const _channelId = 'follow_up_reminders_v2';
  static const _storeKey = 'follow_up_reminder_jobs_v2';
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  Timer? _poll;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: android));
    final plugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await plugin?.requestNotificationsPermission();
    await plugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Follow-up reminders',
      description: 'One reminder before scheduled callbacks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    _ready = true;
    _poll ??= Timer.periodic(const Duration(minutes: 1), (_) => checkDue());
    await syncFromHistory();
    await checkDue();
  }

  Future<void> scheduleForCall(String callId, DateTime followUpAt) async {
    await init();
    final jobs = await _loadJobs();
    final prev = jobs[callId];
    jobs[callId] = _FollowUpJob(
      dueAt: followUpAt,
      notified: prev?.dueAt == followUpAt ? prev!.notified : false,
    );
    await _saveJobs(jobs);
  }

  Future<void> cancelForCall(String callId) async {
    final jobs = await _loadJobs();
    jobs.remove(callId);
    await _saveJobs(jobs);
    await _local.cancel(_notifId(callId));
  }

  /// Ensures every pending follow-up in call history has a reminder job.
  Future<void> syncFromHistory() async {
    await CallHistoryStore.instance.load();
    final jobs = await _loadJobs();
    var changed = false;
    // Skip reminder once the agent already called back.
    for (final call in CallHistoryStore.instance.activeFollowUps()) {
      if (call.followUpCalledAt != null) {
        final prev = jobs[call.id];
        if (prev != null && !prev.notified) {
          jobs[call.id] = prev.copyWith(notified: true);
          changed = true;
        }
        continue;
      }
      final prev = jobs[call.id];
      if (prev == null || prev.dueAt != call.followUpAt) {
        jobs[call.id] = _FollowUpJob(dueAt: call.followUpAt!, notified: false);
        changed = true;
      }
    }
    final activeIds = CallHistoryStore.instance.activeFollowUps().map((c) => c.id).toSet();
    for (final id in jobs.keys.toList()) {
      if (!activeIds.contains(id)) {
        jobs.remove(id);
        changed = true;
      }
    }
    if (changed) await _saveJobs(jobs);
  }

  Future<void> checkDue() async {
    await init();
    await syncFromHistory();
    final jobs = await _loadJobs();
    if (jobs.isEmpty) return;

    final now = DateTime.now();
    final lead = Duration(minutes: AppConfig.followUpReminderMinutes);
    var changed = false;

    for (final entry in jobs.entries.toList()) {
      final callId = entry.key;
      var job = entry.value;
      final due = job.dueAt;
      final remindAt = due.subtract(lead);

      if (now.isAfter(due.add(const Duration(hours: 2)))) {
        jobs.remove(callId);
        changed = true;
        continue;
      }

      if (job.notified || now.isBefore(remindAt) || now.isAfter(due)) {
        continue;
      }

      CallEntity? matched;
      for (final c in CallHistoryStore.instance.items) {
        if (c.id == callId) {
          matched = c;
          break;
        }
      }
      if (matched == null || matched.followUpAt == null) {
        jobs.remove(callId);
        changed = true;
        continue;
      }
      if (matched.followUpCalledAt != null) {
        job = job.copyWith(notified: true);
        jobs[callId] = job;
        changed = true;
        continue;
      }

      final name = matched.displayName?.isNotEmpty == true
          ? matched.displayName!
          : matched.number;
      final number = matched.number;

      await _local.show(
        _notifId(callId),
        'Follow-up in ${AppConfig.followUpReminderMinutes} minutes',
        'Call $number · $name',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Follow-up reminders',
            channelDescription: 'One reminder before scheduled callbacks',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            ticker: 'Follow-up: $number',
          ),
        ),
        payload: 'follow_up:$callId',
      );

      job = job.copyWith(notified: true);
      jobs[callId] = job;
      changed = true;
    }

    if (changed) await _saveJobs(jobs);
  }

  int _notifId(String callId) => callId.hashCode & 0x7fffffff;

  Future<Map<String, _FollowUpJob>> _loadJobs() async {
    final raw = StorageService.getString(_storeKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map;
      return decoded.map((k, v) {
        if (v is Map) {
          return MapEntry(k.toString(), _FollowUpJob.fromJson(Map<String, dynamic>.from(v)));
        }
        // Legacy v1 format: callId -> iso8601 string
        final due = DateTime.tryParse(v.toString());
        return MapEntry(
          k.toString(),
          _FollowUpJob(dueAt: due ?? DateTime.now(), notified: false),
        );
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveJobs(Map<String, _FollowUpJob> jobs) async {
    final encoded = jsonEncode(jobs.map((k, v) => MapEntry(k, v.toJson())));
    await StorageService.setString(_storeKey, encoded);
  }
}
