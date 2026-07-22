import 'contact_tag.dart';

class ContactEntity {
  final String id;
  final String name;
  final String number;
  final String? avatarUrl;
  final bool favorite;
  final bool online;

  /// Optional CRM-style metadata.
  final String? company;
  final String? email;
  final String? notes;

  /// If true, incoming calls from this number are auto-rejected.
  final bool blocked;

  /// Colored CRM tags (VIP, Lead, etc.).
  final List<ContactTag> tags;

  /// Marks contacts imported from the device's phone book.
  final bool fromDevice;

  const ContactEntity({
    required this.id,
    required this.name,
    required this.number,
    this.avatarUrl,
    this.favorite = false,
    this.online = false,
    this.company,
    this.email,
    this.notes,
    this.blocked = false,
    this.tags = const [],
    this.fromDevice = false,
  });

  ContactEntity copyWith({
    String? name,
    String? number,
    String? avatarUrl,
    bool? favorite,
    bool? online,
    String? company,
    String? email,
    String? notes,
    bool? blocked,
    List<ContactTag>? tags,
    bool? fromDevice,
  }) =>
      ContactEntity(
        id: id,
        name: name ?? this.name,
        number: number ?? this.number,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        favorite: favorite ?? this.favorite,
        online: online ?? this.online,
        company: company ?? this.company,
        email: email ?? this.email,
        notes: notes ?? this.notes,
        blocked: blocked ?? this.blocked,
        tags: tags ?? this.tags,
        fromDevice: fromDevice ?? this.fromDevice,
      );
}
