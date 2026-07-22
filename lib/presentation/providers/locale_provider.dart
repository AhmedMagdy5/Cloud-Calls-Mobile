import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/storage_service.dart';

/// `null` means "follow system".
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(_load());

  static Locale? _load() {
    final v = StorageService.getString(StorageKeys.language);
    switch (v) {
      case 'en':
        return const Locale('en');
      case 'ar':
        return const Locale('ar');
      default:
        return null; // system
    }
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await StorageService.remove(StorageKeys.language);
    } else {
      await StorageService.setString(StorageKeys.language, locale.languageCode);
    }
  }
}
