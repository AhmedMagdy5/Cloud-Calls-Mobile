import '../../data/contacts_store.dart';
import '../../data/datasources/api_clients.dart';
import '../../data/sync/offline_sync_queue.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';

class ContactRepositoryImpl implements ContactRepository {
  final VoiceApi _api;
  ContactRepositoryImpl([VoiceApi? api]) : _api = api ?? VoiceApi();

  @override
  Future<List<ContactEntity>> fetchRemote() async {
    try {
      final items = await _api.contacts();
      for (final j in items) {
        await ContactsStore.instance.add(
          name: j['name']?.toString() ?? j['number']?.toString() ?? '',
          number: j['number']?.toString() ?? '',
        );
      }
      await ContactsStore.instance.load();
      return ContactsStore.instance.items;
    } catch (_) {
      await ContactsStore.instance.load();
      return ContactsStore.instance.items;
    }
  }

  @override
  Future<void> pushContact(ContactEntity contact) async {
    try {
      await _api.upsertContact({
        'id': contact.id,
        'name': contact.name,
        'number': contact.number,
        'email': contact.email,
        'company': contact.company,
        'notes': contact.notes,
        'tags': contact.tags.map((t) => t.name).toList(),
      });
    } catch (_) {
      await OfflineSyncQueue.instance.enqueue(
        type: 'contact',
        payload: {
          'id': contact.id,
          'name': contact.name,
          'number': contact.number,
        },
      );
    }
  }
}
