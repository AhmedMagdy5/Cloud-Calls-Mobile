import '../entities/contact_entity.dart';

abstract class ContactRepository {
  Future<List<ContactEntity>> fetchRemote();
  Future<void> pushContact(ContactEntity contact);
}
