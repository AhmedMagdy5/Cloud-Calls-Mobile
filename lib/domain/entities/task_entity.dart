import '../../core/constants/app_config.dart';

enum TaskStatus { pending, done, canceled }

class TaskEntity {
  final String id;
  final String title;
  final String? number;
  final String? callId;
  final DateTime? dueAt;
  final DateTime? followUpCalledAt;
  final DateTime? followUpCompletedAt;
  final String? actionNote;
  final TaskStatus status;
  final DateTime createdAt;

  const TaskEntity({
    required this.id,
    required this.title,
    this.number,
    this.callId,
    this.dueAt,
    this.followUpCalledAt,
    this.followUpCompletedAt,
    this.actionNote,
    this.status = TaskStatus.pending,
    required this.createdAt,
  });

  bool get isCalled => followUpCalledAt != null;

  bool get isCompleted => followUpCompletedAt != null;

  bool get isOverdue =>
      !isCalled &&
      !isCompleted &&
      status == TaskStatus.pending &&
      dueAt != null &&
      dueAt!.isBefore(DateTime.now());

  /// Within the reminder window — agent should call now.
  bool get isDueSoon {
    if (isCalled || isCompleted || status != TaskStatus.pending || dueAt == null) {
      return false;
    }
    final now = DateTime.now();
    if (!dueAt!.isAfter(now)) return false;
    return !now.isBefore(
      dueAt!.subtract(Duration(minutes: AppConfig.followUpReminderMinutes)),
    );
  }

  bool get isLocal => id.startsWith('local:');

  factory TaskEntity.fromJson(Map<String, dynamic> j) => TaskEntity(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? 'Follow-up',
        number: j['number']?.toString(),
        callId: j['callId']?.toString(),
        dueAt: j['dueAt'] != null ? DateTime.tryParse(j['dueAt'].toString()) : null,
        status: TaskStatus.values.firstWhere(
          (e) => e.name == j['status']?.toString(),
          orElse: () => TaskStatus.pending,
        ),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'number': number,
        'callId': callId,
        'dueAt': dueAt?.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };
}
