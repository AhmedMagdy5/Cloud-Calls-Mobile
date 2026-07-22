import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../core/constants/app_config.dart';
import '../sip/sip_service.dart';

/// Keeps SIP registration alive while the app is backgrounded (Android foreground service).
class SipBackgroundService {
  SipBackgroundService._();
  static final instance = SipBackgroundService._();

  bool _configured = false;

  Future<void> init() async {
    if (_configured || kIsWeb) return;

    if (!AppConfig.enableBackgroundSip) {
      await _disableBackgroundService();
      _configured = true;
      return;
    }

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'awfar_sip_service',
        initialNotificationTitle: AppConfig.appName,
        initialNotificationContent: 'Keeping SIP connection alive',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.phoneCall],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
    _configured = true;
  }

  Future<void> _disableBackgroundService() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stop');
    }
  }

  Future<void> start() async {
    if (!_configured) await init();
    final service = FlutterBackgroundService();
    if (await service.isRunning()) return;
    await service.startService();
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('stop').listen((_) => service.stopSelf());
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: AppConfig.appName,
      content: 'SIP registered — ready for calls',
    );
  }

  Timer.periodic(const Duration(seconds: 30), (_) async {
    await SipService.instance.ensureConnected();
    if (service is AndroidServiceInstance) {
      final label = SipService.instance.statusLabel;
      service.setForegroundNotificationInfo(
        title: AppConfig.appName,
        content: label,
      );
    }
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  await SipService.instance.ensureConnected();
  return true;
}
