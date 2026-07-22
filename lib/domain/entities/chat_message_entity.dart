class ChatMessageEntity {
  final String id;
  final String text;
  final String fromUserId;
  final String fromName;
  final String? toUserId;
  final DateTime sentAt;
  final bool isMine;

  const ChatMessageEntity({
    required this.id,
    required this.text,
    required this.fromUserId,
    required this.fromName,
    this.toUserId,
    required this.sentAt,
    this.isMine = false,
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic> j) => ChatMessageEntity(
        id: j['id']?.toString() ?? '',
        text: j['text']?.toString() ?? '',
        fromUserId: j['fromUserId']?.toString() ?? '',
        fromName: j['fromName']?.toString() ?? 'Agent',
        toUserId: j['toUserId']?.toString(),
        sentAt: DateTime.tryParse(j['sentAt']?.toString() ?? '') ?? DateTime.now(),
        isMine: j['isMine'] == true,
      );
}
