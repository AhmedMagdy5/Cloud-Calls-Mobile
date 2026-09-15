import '../../core/constants/app_config.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi _api;
  AuthRepositoryImpl([AuthApi? api]) : _api = api ?? AuthApi();

  @override
  Future<({UserEntity user, SipCredentials sip, String token})> login({
    required String username,
    required String password,
  }) {
    if (!AppConfig.hasBackendConfigured) {
      throw StateError(
        'Configure your API URL in SIP Account settings, or use direct SIP login.',
      );
    }
    return _api.login(username: username, password: password);
  }

  @override
  Future<void> logout() async {
    if (!AppConfig.hasBackendConfigured) return;
    try {
      await _api.logout();
    } catch (_) {}
  }

  @override
  Future<String?> refreshToken() async {
    if (!AppConfig.hasBackendConfigured) return null;
    return _api.refreshToken();
  }
}
