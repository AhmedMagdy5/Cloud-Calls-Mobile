import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<({UserEntity user, SipCredentials sip, String token})> login({
    required String username,
    required String password,
  });
  Future<void> logout();
  Future<String?> refreshToken();
}
