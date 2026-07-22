import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../core/services/storage_service.dart';
import '../domain/entities/contact_entity.dart';
import '../domain/entities/contact_tag.dart';


/// Persistent user contacts store (SharedPreferences-backed JSON).
class ContactsStore extends ChangeNotifier {
  ContactsStore._();
  static final instance = ContactsStore._();

  static const _key = 'contacts_v3';
  final List<ContactEntity> _items = [];
  bool _loaded = false;

  List<ContactEntity> get items => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    final raw = StorageService.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .map(_fromJson));
        }
      } catch (e) {
        debugPrint('[Contacts] load error: $e');
      }
    }
    // No mock seeding — start with an empty contacts list.
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_items.map(_toJson).toList());
    await StorageService.setString(_key, raw);
  }

  Future<void> add({
    required String name,
    required String number,
    bool favorite = false,
    String? company,
    String? email,
    String? notes,
    bool blocked = false,
    List<ContactTag> tags = const [],
    bool fromDevice = false,
  }) async {
    if (!_loaded) await load();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _items.insert(0, ContactEntity(
      id: id,
      name: name.trim(),
      number: number.trim(),
      favorite: favorite,
      company: company,
      email: email,
      notes: notes,
      blocked: blocked,
      tags: tags,
      fromDevice: fromDevice,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> update(ContactEntity c) async {
    if (!_loaded) await load();
    final i = _items.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      _items[i] = c;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    if (!_loaded) await load();
    _items.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    if (!_loaded) await load();
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(favorite: !_items[i].favorite);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> toggleBlocked(String id) async {
    if (!_loaded) await load();
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(blocked: !_items[i].blocked);
      await _persist();
      notifyListeners();
    }
  }

  /// Returns true if the given incoming number matches a blocked contact.
  bool isBlocked(String number) {
    final n = _normalize(number);
    if (n.isEmpty) return false;
    for (final c in _items) {
      if (c.blocked && _normalize(c.number) == n) return true;
    }
    return false;
  }

  ContactEntity? findByNumber(String number) {
    final n = _normalize(number);
    if (n.isEmpty) return null;
    for (final c in _items) {
      if (_normalize(c.number) == n) return c;
    }
    return null;
  }

  String _normalize(String s) => s.replaceAll(RegExp(r'[^0-9+*#]'), '');

  /// Import contacts from the device's phone book. Returns the count imported.
  /// Skips duplicates by normalized number.
  Future<({int added, int skipped})> importFromDevice() async {
    if (!_loaded) await load();

    // Permission
    final st = await Permission.contacts.request();
    if (!st.isGranted) {
      throw StateError('Contacts permission denied');
    }

    final granted = await fc.FlutterContacts.requestPermission(readonly: true);
    if (!granted) throw StateError('Contacts permission denied');

    final deviceContacts =
        await fc.FlutterContacts.getContacts(withProperties: true);

    int added = 0;
    int skipped = 0;
    final existing = _items.map((c) => _normalize(c.number)).toSet();

    for (final dc in deviceContacts) {
      if (dc.phones.isEmpty) continue;
      final name = dc.displayName.trim().isEmpty
          ? (dc.phones.first.number)
          : dc.displayName.trim();
      for (final p in dc.phones) {
        final num = p.number.trim();
        if (num.isEmpty) continue;
        final key = _normalize(num);
        if (key.isEmpty || existing.contains(key)) {
          skipped++;
          continue;
        }
        existing.add(key);
        final id = '${DateTime.now().microsecondsSinceEpoch}_$added';
        _items.add(ContactEntity(
          id: id,
          name: name,
          number: num,
          email: dc.emails.isNotEmpty ? dc.emails.first.address : null,
          company: dc.organizations.isNotEmpty
              ? dc.organizations.first.company
              : null,
          fromDevice: true,
        ));
        added++;
      }
    }
    // Sort alphabetically.
    _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _persist();
    notifyListeners();
    return (added: added, skipped: skipped);
  }

  Map<String, dynamic> _toJson(ContactEntity c) => {
        'id': c.id,
        'name': c.name,
        'number': c.number,
        'avatarUrl': c.avatarUrl,
        'favorite': c.favorite,
        'online': c.online,
        'company': c.company,
        'email': c.email,
        'notes': c.notes,
        'blocked': c.blocked,
        'tags': c.tags.map((t) => t.name).toList(),
        'fromDevice': c.fromDevice,
      };

  ContactEntity _fromJson(Map<String, dynamic> j) => ContactEntity(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        number: j['number'] ?? '',
        avatarUrl: j['avatarUrl'],
        favorite: j['favorite'] == true,
        online: j['online'] == true,
        company: j['company'],
        email: j['email'],
        notes: j['notes'],
        blocked: j['blocked'] == true,
        tags: ContactTagX.parseList(j['tags']),
        fromDevice: j['fromDevice'] == true,
      );
}
