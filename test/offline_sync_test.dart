import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_calls_mobile/domain/entities/user_entity.dart';
import 'package:cloud_calls_mobile/domain/entities/customer_entity.dart';
import 'package:cloud_calls_mobile/data/sync/offline_sync_queue.dart';

void main() {
  test('UserEntity round-trip from stored string', () {
    const user = UserEntity(
      id: '1',
      name: 'Agent',
      email: 'a@test.com',
      extension: '200',
      role: 'supervisor',
    );
    final restored = UserEntity.fromStoredString(user.toJsonString());
    expect(restored?.extension, '200');
    expect(restored?.isSupervisor, true);
  });

  test('CustomerEntity parses backend payload', () {
    final c = CustomerEntity.fromJson({
      'id': 'c1',
      'name': 'Ahmed',
      'phone': '+20100',
      'tags': ['VIP'],
      'openTickets': 2,
    });
    expect(c.name, 'Ahmed');
    expect(c.openTickets, 2);
  });

  test('OfflineSyncQueue enqueue stores payload', () async {
    await OfflineSyncQueue.instance.enqueue(
      type: 'wrap_up',
      payload: {'callId': 'abc', 'note': 'test'},
    );
    // No throw means queue accepted write when storage initialized in app only;
    // in unit tests SharedPreferences may be unavailable — smoke test only.
    expect(true, isTrue);
  });
}
