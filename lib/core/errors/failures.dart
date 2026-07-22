sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure { const NetworkFailure(super.m); }
class AuthFailure extends Failure { const AuthFailure(super.m); }
class SipFailure extends Failure { const SipFailure(super.m); }
class ServerFailure extends Failure { const ServerFailure(super.m); }
class CacheFailure extends Failure { const CacheFailure(super.m); }
class UnknownFailure extends Failure { const UnknownFailure(super.m); }
