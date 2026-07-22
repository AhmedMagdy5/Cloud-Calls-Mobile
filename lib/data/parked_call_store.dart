import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/services/storage_service.dart';
import '../domain/entities/parked_call_entity.dart';

/// Tracks calls held locally while the agent makes other calls.
class ParkedCallStore extends ChangeNotifier {
  ParkedCallStore._();
  static final instance = ParkedCallStore._();

  static const _key = 'parked_calls_v1';
  final List<ParkedCallEntity> _items = [];
  bool _loaded = false;

  List<ParkedCallEntity> get items => List.unmodifiable(_items);

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
                .map(ParkedCallEntity.fromJson)
                .where((p) => p.id.isNotEmpty));
        }
      } catch (e) {
        debugPrint('[ParkedCall] load error: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await StorageService.setString(_key, raw);
  }

  Future<void> add(ParkedCallEntity call) async {
    if (!_loaded) await load();
    _items.removeWhere((p) => p.slot == call.slot || p.id == call.id);
    _items.insert(0, call);
    await _persist();
    notifyListeners();
  }

  Future<void> removeBySlot(String slot) async {
    if (!_loaded) await load();
    _items.removeWhere((p) => p.slot == slot);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    if (!_loaded) await load();
    _items.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  ParkedCallEntity? findById(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  ParkedCallEntity? findBySlot(String slot) {
    for (final p in _items) {
      if (p.slot == slot) return p;
    }
    return null;
  }
}
