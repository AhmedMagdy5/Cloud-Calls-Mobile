class QueueEntity {
  final String id;
  final String name;
  final int waiting;
  final int longestWaitSec;
  final bool loggedIn;
  final bool paused;

  const QueueEntity({
    required this.id,
    required this.name,
    this.waiting = 0,
    this.longestWaitSec = 0,
    this.loggedIn = false,
    this.paused = false,
  });

  factory QueueEntity.fromJson(Map<String, dynamic> j) => QueueEntity(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Queue',
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        longestWaitSec: (j['longestWaitSec'] as num?)?.toInt() ?? 0,
        loggedIn: j['loggedIn'] == true,
        paused: j['paused'] == true,
      );
}
