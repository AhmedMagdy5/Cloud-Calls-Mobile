enum CallDirection { incoming, outgoing }
enum CallStatus {
  idle,
  ringing,
  connecting,
  active,
  held,
  ended,
  failed,
  missed,
  // Extended terminal states mapped from Asterisk / Q.850 / SIP cause codes.
  busy,        // 486 / 600 / Q.850 17 — callee busy
  declined,    // 603 / 403 / 401 / 407 / Q.850 21 — call rejected
  noAnswer,    // 408 / 480 / 487 / Q.850 18,19 — no answer / cancelled by us before pickup
  unavailable, // 404 / 410 / 484 / 485 / 604 / Q.850 1,22,28 — unallocated / out of order
  canceled,    // local CANCEL before remote answered (originator=local on ENDED)
}

/// True for any status that means the call is no longer active.
extension CallStatusX on CallStatus {
  bool get isTerminal => switch (this) {
        CallStatus.ended ||
        CallStatus.failed ||
        CallStatus.missed ||
        CallStatus.busy ||
        CallStatus.declined ||
        CallStatus.noAnswer ||
        CallStatus.unavailable ||
        CallStatus.canceled =>
          true,
        _ => false,
      };
}

/// Disposition tags an agent can apply after a call (CRM-style).
enum CallDisposition {
  none,
  interested,
  notInterested,
  callback,
  voicemail,
  wrongNumber,
  noAnswer,
  closed,
  spam,
}

extension CallDispositionX on CallDisposition {
  String get label => switch (this) {
        CallDisposition.none => 'No tag',
        CallDisposition.interested => 'Interested',
        CallDisposition.notInterested => 'Not interested',
        CallDisposition.callback => 'Call back',
        CallDisposition.voicemail => 'Voicemail',
        CallDisposition.wrongNumber => 'Wrong number',
        CallDisposition.noAnswer => 'No answer',
        CallDisposition.closed => 'Closed',
        CallDisposition.spam => 'Spam',
      };
}

class CallEntity {
  final String id;
  final String number;
  final String? displayName;
  final CallDirection direction;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final bool muted;
  final bool onHold;
  final bool speakerOn;
  final bool recording;

  /// Free-form note the agent wrote about this call.
  final String? note;

  /// CRM-style outcome tag.
  final CallDisposition disposition;

  /// Optional scheduled follow-up timestamp.
  final DateTime? followUpAt;

  /// When the agent placed the follow-up callback from Tasks.
  final DateTime? followUpCalledAt;

  /// Note recorded when closing the follow-up task (✓).
  final String? followUpActionNote;

  /// When the follow-up was fully closed from Tasks (✓).
  final DateTime? followUpCompletedAt;

  /// Human-readable end reason derived from SIP/Q.850 cause (e.g. "User busy").
  final String? endReason;

  /// Raw SIP response code that ended the call, when known (e.g. 486).
  final int? hangupCode;

  const CallEntity({
    required this.id,
    required this.number,
    this.displayName,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.muted = false,
    this.onHold = false,
    this.speakerOn = false,
    this.recording = false,
    this.note,
    this.disposition = CallDisposition.none,
    this.followUpAt,
    this.followUpCalledAt,
    this.followUpActionNote,
    this.followUpCompletedAt,
    this.endReason,
    this.hangupCode,
  });

  Duration get duration {
    if (answeredAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(answeredAt!);
  }

  CallEntity copyWith({
    CallStatus? status,
    DateTime? answeredAt,
    DateTime? endedAt,
    bool? muted,
    bool? onHold,
    bool? speakerOn,
    bool? recording,
    String? displayName,
    String? note,
    CallDisposition? disposition,
    DateTime? followUpAt,
    DateTime? followUpCalledAt,
    String? followUpActionNote,
    DateTime? followUpCompletedAt,
    bool clearFollowUp = false,
    bool clearFollowUpCalled = false,
    bool clearFollowUpCompleted = false,
    String? endReason,
    int? hangupCode,
  }) =>
      CallEntity(
        id: id,
        number: number,
        displayName: displayName ?? this.displayName,
        direction: direction,
        status: status ?? this.status,
        startedAt: startedAt,
        answeredAt: answeredAt ?? this.answeredAt,
        endedAt: endedAt ?? this.endedAt,
        muted: muted ?? this.muted,
        onHold: onHold ?? this.onHold,
        speakerOn: speakerOn ?? this.speakerOn,
        recording: recording ?? this.recording,
        note: note ?? this.note,
        disposition: disposition ?? this.disposition,
        followUpAt: clearFollowUp ? null : (followUpAt ?? this.followUpAt),
        followUpCalledAt:
            clearFollowUpCalled ? null : (followUpCalledAt ?? this.followUpCalledAt),
        followUpActionNote: followUpActionNote ?? this.followUpActionNote,
        followUpCompletedAt: clearFollowUpCompleted
            ? null
            : (followUpCompletedAt ?? this.followUpCompletedAt),
        endReason: endReason ?? this.endReason,
        hangupCode: hangupCode ?? this.hangupCode,
      );
}
