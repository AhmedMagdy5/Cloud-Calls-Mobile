import 'call_entity.dart';

class TranscriptChunk {
  final String speaker;
  final String text;
  final DateTime at;

  const TranscriptChunk({
    required this.speaker,
    required this.text,
    required this.at,
  });

  factory TranscriptChunk.fromJson(Map<String, dynamic> j) => TranscriptChunk(
        speaker: j['speaker']?.toString() ?? 'unknown',
        text: j['text']?.toString() ?? '',
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AgentAssistSummary {
  final String summary;
  final CallDisposition? suggestedDisposition;
  final List<String> keyPoints;
  final String? sentiment;

  const AgentAssistSummary({
    required this.summary,
    this.suggestedDisposition,
    this.keyPoints = const [],
    this.sentiment,
  });

  factory AgentAssistSummary.fromJson(Map<String, dynamic> j) {
    CallDisposition? disp;
    final raw = j['suggestedDisposition']?.toString();
    if (raw != null) {
      disp = CallDisposition.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => CallDisposition.none,
      );
      if (disp == CallDisposition.none) disp = null;
    }
    return AgentAssistSummary(
      summary: j['summary']?.toString() ?? '',
      suggestedDisposition: disp,
      keyPoints: (j['keyPoints'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      sentiment: j['sentiment']?.toString(),
    );
  }
}
