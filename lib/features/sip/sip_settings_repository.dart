import 'dart:convert';
import '../../core/services/storage_service.dart';
import '../../domain/entities/user_entity.dart';

/// Persists [SipCredentials] across app launches.
/// - Non-sensitive fields → SharedPreferences (JSON).
/// - Passwords (SIP + TURN) → FlutterSecureStorage.
class SipSettingsRepository {
  static const _kJson = 'sip_settings_json';
  static const _kTurnPwd = 'sip_turn_password';
  static const _kSaveLogin = 'sip_save_login';

  bool get shouldSaveLogin => StorageService.getBool(_kSaveLogin);

  Future<void> save(SipCredentials c, {bool remember = true}) async {
    await StorageService.setBool(_kSaveLogin, remember);
    if (!remember) {
      await clear(clearRememberFlag: false);
      return;
    }
    await StorageService.setString(_kJson, jsonEncode(c.toJson()));
    await StorageService.setSecure(StorageKeys.sipPassword, c.password);
    await StorageService.setSecure(StorageKeys.sipUsername, c.username);
    await StorageService.setSecure(StorageKeys.sipServer, c.server);
    if (c.turnPassword != null && c.turnPassword!.isNotEmpty) {
      await StorageService.setSecure(_kTurnPwd, c.turnPassword!);
    } else {
      await StorageService.deleteSecure(_kTurnPwd);
    }
  }

  Future<SipCredentials?> load() async {
    if (!shouldSaveLogin) return null;
    final raw = StorageService.getString(_kJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final pwd = await StorageService.getSecure(StorageKeys.sipPassword) ?? '';
      final turn = await StorageService.getSecure(_kTurnPwd);
      return SipCredentials.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
        password: pwd,
        turnPassword: turn,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear({bool clearRememberFlag = true}) async {
    await StorageService.remove(_kJson);
    await StorageService.deleteSecure(StorageKeys.sipPassword);
    await StorageService.deleteSecure(StorageKeys.sipUsername);
    await StorageService.deleteSecure(StorageKeys.sipServer);
    await StorageService.deleteSecure(_kTurnPwd);
    if (clearRememberFlag) await StorageService.remove(_kSaveLogin);
  }
}
