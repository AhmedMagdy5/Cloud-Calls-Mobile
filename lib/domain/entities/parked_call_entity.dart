import 'call_entity.dart';

class ParkedCallEntity {
  final String id;
  final String customerNumber;
  final String? customerName;
  final String slot;
  final DateTime parkedAt;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final CallDirection direction;

  const ParkedCallEntity({
    required this.id,
    required this.customerNumber,
    this.customerName,
    required this.slot,
    required this.parkedAt,
    required this.startedAt,
    this.answeredAt,
    this.direction = CallDirection.incoming,
  });

  String get label =>
      customerName?.trim().isNotEmpty == true ? customerName!.trim() : customerNumber;

  CallEntity toCallEntity() => CallEntity(
        id: id,
        number: customerNumber,
        displayName: customerName,
        direction: direction,
        status: CallStatus.held,
        startedAt: startedAt,
        answeredAt: answeredAt,
        onHold: true,
      );

  ParkedCallEntity copyWith({
    String? slot,
    String? customerName,
  }) =>
      ParkedCallEntity(
        id: id,
        customerNumber: customerNumber,
        customerName: customerName ?? this.customerName,
        slot: slot ?? this.slot,
        parkedAt: parkedAt,
        startedAt: startedAt,
        answeredAt: answeredAt,
        direction: direction,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerNumber': customerNumber,
        'customerName': customerName,
        'slot': slot,
        'parkedAt': parkedAt.toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
        'answeredAt': answeredAt?.toIso8601String(),
        'direction': direction.name,
      };

  factory ParkedCallEntity.fromJson(Map<String, dynamic> j) => ParkedCallEntity(
        id: j['id']?.toString() ?? '',
        customerNumber: j['customerNumber']?.toString() ?? '',
        customerName: j['customerName']?.toString(),
        slot: j['slot']?.toString() ?? '',
        parkedAt: DateTime.tryParse(j['parkedAt']?.toString() ?? '') ?? DateTime.now(),
        startedAt: DateTime.tryParse(j['startedAt']?.toString() ?? '') ??
            DateTime.tryParse(j['parkedAt']?.toString() ?? '') ??
            DateTime.now(),
        answeredAt: j['answeredAt'] != null
            ? DateTime.tryParse(j['answeredAt'].toString())
            : null,
        direction: CallDirection.values.asNameMap()[j['direction']?.toString()] ??
            CallDirection.incoming,
      );
}
