import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/call_entity.dart';

class MockData {
  static List<ContactEntity> contacts = const [
    ContactEntity(id: '1', name: 'Ahmed Al-Sayed', number: '+966501234567', favorite: true, online: true),
    ContactEntity(id: '2', name: 'Sara Mohamed', number: '+966509876543', favorite: true),
    ContactEntity(id: '3', name: 'Omar Khaled', number: '2101', online: true),
    ContactEntity(id: '4', name: 'Layla Nasser', number: '+201012345678'),
    ContactEntity(id: '5', name: 'Karim Hassan', number: '2105'),
    ContactEntity(id: '6', name: 'Nour Ibrahim', number: '+966551112233', favorite: true),
  ];

  static List<CallEntity> history = [
    CallEntity(id: 'h1', number: '+966501234567', displayName: 'Ahmed Al-Sayed', direction: CallDirection.outgoing, status: CallStatus.ended, startedAt: DateTime.now().subtract(const Duration(minutes: 12)), answeredAt: DateTime.now().subtract(const Duration(minutes: 12)), endedAt: DateTime.now().subtract(const Duration(minutes: 9))),
    CallEntity(id: 'h2', number: '2101', displayName: 'Omar Khaled', direction: CallDirection.incoming, status: CallStatus.missed, startedAt: DateTime.now().subtract(const Duration(hours: 2))),
    CallEntity(id: 'h3', number: '+966509876543', displayName: 'Sara Mohamed', direction: CallDirection.incoming, status: CallStatus.ended, startedAt: DateTime.now().subtract(const Duration(hours: 5)), answeredAt: DateTime.now().subtract(const Duration(hours: 5)), endedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 58))),
  ];
}
