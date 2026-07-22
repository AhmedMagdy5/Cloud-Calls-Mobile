import 'package:flutter/material.dart';
import '../../core/i18n/app_strings.dart';

/// Reason an agent gives when going Offline or DND.
enum BreakReason {
  meeting,
  training,
  lunch,
  personal,
  admin,
  prayer,
  breakTime,
  other,
}

extension BreakReasonX on BreakReason {
  String get apiValue => switch (this) {
        BreakReason.meeting => 'meeting',
        BreakReason.training => 'training',
        BreakReason.lunch => 'lunch',
        BreakReason.personal => 'personal',
        BreakReason.admin => 'admin',
        BreakReason.prayer => 'prayer',
        BreakReason.breakTime => 'break',
        BreakReason.other => 'other',
      };

  String label(BuildContext context) {
    final s = S.of(context);
    return switch (this) {
      BreakReason.meeting => s.reasonMeeting,
      BreakReason.training => s.reasonTraining,
      BreakReason.lunch => s.reasonLunch,
      BreakReason.personal => s.reasonPersonal,
      BreakReason.admin => s.reasonAdmin,
      BreakReason.prayer => s.reasonPrayer,
      BreakReason.breakTime => s.reasonBreak,
      BreakReason.other => s.reasonOther,
    };
  }

  IconData get icon => switch (this) {
        BreakReason.meeting => Icons.groups,
        BreakReason.training => Icons.school,
        BreakReason.lunch => Icons.restaurant,
        BreakReason.personal => Icons.person,
        BreakReason.admin => Icons.assignment,
        BreakReason.prayer => Icons.self_improvement,
        BreakReason.breakTime => Icons.local_cafe,
        BreakReason.other => Icons.more_horiz,
      };
}

class BreakReasonResult {
  final BreakReason reason;
  final String? customReason;
  const BreakReasonResult(this.reason, [this.customReason]);
}
