import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/backend_settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/datasources/mobile_presence_api.dart';
import '../../domain/entities/call_entity.dart';
import '../sip/sip_service.dart';

/// Sends supervisor presence (online / dnd / incall) to `mobile_presence.php`.
class MobilePresenceService {
  MobilePresenceService._();
  static final instance = MobilePresenceService._();

  final MobilePresenceApi _api = MobilePresenceApi();
  Timer? _heartbeat;
  String? _token;
  String? _extension;
  bool _busy = false;

  bool get isEnabled => BackendSettingsService.instance.isPresenceConfigured;

  Future<void> onSipRegistered() async {
    if (!isEnabled) return;
    final extension = _resolveExtension();
    if (extension == null || extension.isEmpty) {
      debugPrint('[MobilePresence] missing extension — skipped');
      return;
    }

    final extensionChanged =
        _extension != null && _extension != extension;
    if (_token != null && !extensionChanged && _heartbeat != null) {
      // SIP refreshed its registration — presence session is still valid.
      return;
    }

    if (extensionChanged && _token != null) {
      await stop(logout: true);
    }

    _extension = extension;
    await _register(force: _token == null || extensionChanged);
    _startHeartbeat();
    await _sendStatusImmediate();
  }

  /// After backend URL/secret change without SIP reconnect.
  Future<void> refreshAfterBackendSettingsChange() async {
    if (!isEnabled) {
      await stop(logout: false);
      return;
    }
    _heartbeat?.cancel();
    _heartbeat = null;
    await stop(logout: true);
    if (SipService.instance.isRegistered) {
      await onSipRegistered();
    }
  }

  Future<void> syncFromSip() async {
    if (!isEnabled || _token == null) return;
    await _sendStatusImmediate();
  }

  Future<void> onPresenceChanged() async {
    if (!isEnabled) return;
    if (SipService.instance.presence == PresenceMode.offline) {
      await stop(logout: true);
      return;
    }
    if (_token == null) {
      await onSipRegistered();
      return;
    }
    await _sendStatusImmediate();
  }

  Future<void> ensureRunning() async {
    if (!isEnabled) return;
    if (!SipService.instance.isRegistered) return;
    if (_token == null) {
      await onSipRegistered();
      return;
    }
    if (_heartbeat == null) _startHeartbeat();
  }

  Future<void> stop({bool logout = false}) async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final token = _token;
    _token = null;
    if (logout && token != null && token.isNotEmpty) {
      try {
        await _api.logout(token: token);
      } catch (e) {
        debugPrint('[MobilePresence] logout failed: $e');
      }
    }
    if (logout) {
      await StorageService.deleteSecure(StorageKeys.presenceToken);
    }
  }

  String? _resolveExtension() {
    final creds = SipService.instance.credentials;
    if (creds != null && creds.username.trim().isNotEmpty) {
      return creds.username.trim();
    }
    return null;
  }

  String _currentStatus() {
    final call = SipService.instance.activeCall;
    if (call != null && !call.status.isTerminal) {
      return 'incall';
    }
    switch (SipService.instance.presence) {
      case PresenceMode.dnd:
        return 'dnd';
      case PresenceMode.online:
        return 'online';
      case PresenceMode.offline:
        return 'online';
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_sendStatus());
    });
  }

  Future<void> _sendStatusImmediate() => _sendStatus(force: true);

  Future<void> _sendStatus({bool force = false}) async {
    if (!isEnabled || _token == null || _extension == null) return;
    if (SipService.instance.presence == PresenceMode.offline) return;
    if (_busy && !force) return;

    _busy = true;
    try {
      await _api.sendStatus(
        extension: _extension!,
        status: _currentStatus(),
        token: _token!,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[MobilePresence] token expired — re-registering');
        await _register(force: true);
        if (_token != null) {
          await _api.sendStatus(
            extension: _extension!,
            status: _currentStatus(),
            token: _token!,
          );
        }
      } else {
        debugPrint('[MobilePresence] status failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('[MobilePresence] status failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _register({required bool force}) async {
    final extension = _extension ?? _resolveExtension();
    if (extension == null || extension.isEmpty) return;

    if (!force) {
      final cached = await StorageService.getSecure(StorageKeys.presenceToken);
      if (cached != null && cached.isNotEmpty) {
        _token = cached;
        _extension = extension;
        return;
      }
    }

    final secret = BackendSettingsService.instance.registrationSecret;
    if (secret.isEmpty) {
      debugPrint('[MobilePresence] registration secret missing');
      return;
    }

    final response = await _api.register(
      extension: extension,
      registrationSecret: secret,
    );
    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Presence register returned no token');
    }
    _token = token;
    _extension = extension;
    await StorageService.setSecure(StorageKeys.presenceToken, token);
    debugPrint('[MobilePresence] registered extension=$extension');
  }
}
