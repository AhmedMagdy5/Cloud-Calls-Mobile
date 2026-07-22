import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../features/sip/sip_service.dart';
import '../../features/sip/sip_settings_repository.dart';
import '../../features/push/push_service.dart';
import '../../features/presence/mobile_presence_service.dart';
import '../../features/background/sip_background_service.dart';
import '../../data/sync/offline_sync_queue.dart';
import '../../core/utils/login_error_message.dart';
import 'repository_providers.dart';

final sipServiceProvider = Provider((_) => SipService.instance);
final sipRepoProvider = Provider((_) => SipSettingsRepository());

/// Reactive view of [SipService] state for the UI.
final sipStatusProvider = ChangeNotifierProvider<SipService>((ref) {
  return ref.watch(sipServiceProvider);
});

/// Saved credentials loaded from secure storage (null until first save).
final savedSipProvider = FutureProvider<SipCredentials?>((ref) async {
  return ref.read(sipRepoProvider).load();
});

class AuthState {
  final UserEntity? user;
  final SipCredentials? sip;
  final bool loading;
  final String? error;
  final bool useBackendAuth;
  const AuthState({
    this.user,
    this.sip,
    this.loading = false,
    this.error,
    this.useBackendAuth = false,
  });
  AuthState copyWith({
    UserEntity? user,
    SipCredentials? sip,
    bool? loading,
    String? error,
    bool? useBackendAuth,
  }) =>
      AuthState(
        user: user ?? this.user,
        sip: sip ?? this.sip,
        loading: loading ?? this.loading,
        error: error,
        useBackendAuth: useBackendAuth ?? this.useBackendAuth,
      );
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;
  AuthController(this.ref) : super(const AuthState()) {
    _restoreProfile();
  }

  Future<void> _restoreProfile() async {
    if (!AppConfig.hasBackendConfigured) return;
    final profile = UserEntity.fromStoredString(
      StorageService.getString(StorageKeys.userProfile),
    );
    if (profile != null) {
      state = state.copyWith(user: profile, useBackendAuth: true);
    }
  }

  Future<void> _startBackgroundSipSafely() async {
    if (!AppConfig.enableBackgroundSip) return;
    try {
      await SipBackgroundService.instance.start();
    } catch (e, st) {
      debugPrint('[Background] start skipped: $e\n$st');
    }
  }

  /// REST login — fetches user + SIP creds from backend.
  Future<bool> loginWithBackend({
    required String username,
    required String password,
    bool rememberLogin = true,
  }) async {
    if (!AppConfig.hasBackendConfigured) {
      state = state.copyWith(
        loading: false,
        error:
            'Configure your API URL in SIP Account settings, or use direct SIP login.',
      );
      return false;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await ref.read(authRepositoryProvider).login(
            username: username,
            password: password,
          );
      final repo = ref.read(sipRepoProvider);
      await repo.save(result.sip, remember: rememberLogin);

      state = AuthState(
        user: result.user,
        sip: result.sip,
        useBackendAuth: true,
      );

      await ref.read(sipServiceProvider).connect(result.sip);
      await PushService.instance.registerToken();
      await _startBackgroundSipSafely();
      await OfflineSyncQueue.instance.flush();
      ref.invalidate(savedSipProvider);
      return true;
    } catch (e) {
      state = AuthState(loading: false, error: loginErrorMessage(e));
      return false;
    }
  }

  /// Direct SIP login — saves credentials, registers, navigates on success.
  Future<bool> loginWithSip({
    required String username,
    required String password,
    String? domain,
    bool rememberLogin = true,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(sipRepoProvider);
      final existing = await repo.load();
      final base = existing ?? SipCredentials.empty;
      final server =
          (domain != null && domain.isNotEmpty) ? domain.trim() : base.server;
      if (server.isEmpty) {
        throw StateError(
          'FreePBX server IP or domain is required.',
        );
      }
      final creds = base.copyWith(
        username: username,
        password: password,
        server: server,
        displayName: username,
      );
      await repo.save(creds, remember: rememberLogin);

      final user = UserEntity(
        id: username,
        name: username,
        email: '',
        extension: username,
      );
      state = AuthState(user: user, sip: creds);

      await ref.read(sipServiceProvider).connect(creds);
      await PushService.instance.registerToken();
      await _startBackgroundSipSafely();
      ref.invalidate(savedSipProvider);
      return true;
    } catch (e) {
      state = AuthState(loading: false, error: loginErrorMessage(e));
      return false;
    }
  }

  Future<void> applySipSettings(SipCredentials creds, {bool reconnect = true}) async {
    final repo = ref.read(sipRepoProvider);
    await repo.save(creds, remember: repo.shouldSaveLogin);
    state = state.copyWith(sip: creds);
    if (reconnect) {
      await ref.read(sipServiceProvider).reapplyCredentials(creds);
    }
    ref.invalidate(savedSipProvider);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {}
    await MobilePresenceService.instance.stop(logout: true);
    await ref.read(sipServiceProvider).disconnect();
    await ref.read(sipRepoProvider).clear();
    if (AppConfig.enableBackgroundSip) {
      try {
        await SipBackgroundService.instance.stop();
      } catch (_) {}
    }
    state = const AuthState();
    ref.invalidate(savedSipProvider);
  }

  Future<bool> login(String u, String p) => loginWithSip(username: u, password: p);
}
