import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/storage_service.dart';
import '../../data/datasources/api_clients.dart';
import '../../domain/entities/user_entity.dart';
import '../sip/sip_service.dart';

/// Executes remote commands from web CRM / webphone (poll + FCM push).
class WebphoneIntegrationService {
  WebphoneIntegrationService._();
  static final instance = WebphoneIntegrationService._();

  final IntegrationApi _api = IntegrationApi();
  Timer? _poll;
  bool _busy = false;

  /// Called when web sends dial/prefill — set from [main.dart] for navigation.
  void Function(String number, {required bool autoDial})? onRemoteDial;

  void start({UserEntity? user}) {
    if (_poll != null) return;
    if (!AppConfig.hasBackendConfigured) {
      debugPrint('[WebphoneIntegration] backend not configured — disabled');
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollCommands(user));
    debugPrint('[WebphoneIntegration] polling started');
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _busy = false;
  }

  /// Handle FCM data payload (instant delivery when app is open/background).
  Future<void> handlePushPayload(Map<String, dynamic> data) async {
    if (!AppConfig.hasBackendConfigured) return;
    final action = data['action']?.toString() ?? 'dial';
    await _executeCommand({
      'id': data['commandId']?.toString(),
      'action': action,
      'number': data['number']?.toString(),
      'dtmf': data['dtmf']?.toString(),
      'autoDial': data['autoDial']?.toString() != 'false',
    }, fromPush: true);
  }

  Future<void> _pollCommands(UserEntity? user) async {
    if (_busy) return;
    _busy = true;
    try {
      final extension = user?.extension ??
          UserEntity.fromStoredString(
            StorageService.getString(StorageKeys.userProfile),
          )?.extension;
      if (extension == null || extension.isEmpty) return;

      final items = await _api.pullCommands();
      for (final cmd in items) {
        await _executeCommand(cmd);
      }
    } catch (e) {
      debugPrint('[WebphoneIntegration] poll failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _executeCommand(
    Map<String, dynamic> cmd, {
    bool fromPush = false,
  }) async {
    final id = cmd['id']?.toString();
    final action = (cmd['action']?.toString() ?? '').toLowerCase();
    final autoDial = cmd['autoDial'] != false;

    try {
      switch (action) {
        case 'dial':
          final number = cmd['number']?.toString() ?? '';
          if (number.isEmpty) throw StateError('Missing number');
          if (onRemoteDial != null) {
            onRemoteDial!(number, autoDial: autoDial);
          } else if (autoDial) {
            await SipService.instance.ensureConnected();
            await SipService.instance.makeCall(number);
          }
          break;
        case 'prefill':
          final number = cmd['number']?.toString() ?? '';
          if (number.isEmpty) throw StateError('Missing number');
          onRemoteDial?.call(number, autoDial: false);
          break;
        case 'hangup':
          SipService.instance.hangup();
          break;
        case 'hold':
          SipService.instance.hold();
          break;
        case 'unhold':
          SipService.instance.unhold();
          break;
        case 'park':
          SipService.instance.parkCurrentCall();
          break;
        case 'answer':
          SipService.instance.answer();
          break;
        case 'dtmf':
          final tone = cmd['dtmf']?.toString() ?? '';
          if (tone.isEmpty) throw StateError('Missing dtmf');
          SipService.instance.sendDtmf(tone);
          break;
        default:
          throw StateError('Unknown action: $action');
      }
      if (id != null && !fromPush) {
        await _api.ackCommand(id, status: 'executed');
      }
    } catch (e) {
      debugPrint('[WebphoneIntegration] command failed ($action): $e');
      if (id != null && !fromPush) {
        await _api.ackCommand(id, status: 'failed', error: e.toString());
      }
    }
  }
}
