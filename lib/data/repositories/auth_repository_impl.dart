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
  }) =>
      _api.login(username: username, password: password);

  @override
  Future<void> logout() => _api.logout();

  @override
  Future<String?> refreshToken() => _api.refreshToken();
}
