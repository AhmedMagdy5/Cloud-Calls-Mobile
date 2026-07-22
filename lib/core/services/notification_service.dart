import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push + local notifications. Owns the high-priority "incoming_calls" channel
/// used to surface a full-screen call notification while the app is in the
/// background or the screen is locked.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _incomingChannelId = 'incoming_calls_alarm_v4';
  static const _incomingChannelName = 'Incoming calls';
  static const incomingNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  String? token;
  bool _channelsReady = false;
  bool _localReady = false;
  bool _fcmReady = false;
  VoidCallback? _onIncomingCallTap;
  bool _pendingIncomingCallTap = false;

  set onIncomingCallTap(VoidCallback? callback) {
    _onIncomingCallTap = callback;
    if (callback != null && _pendingIncomingCallTap) {
      _pendingIncomingCallTap = false;
      callback();
    }
  }

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onTap,
    );
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload == 'incoming_call') {
      _pendingIncomingCallTap = true;
    }
    _localReady = true;

    await _ensureChannels();

    if (_fcmReady || Firebase.apps.isEmpty) {
      debugPrint('Firebase messaging skipped: no default Firebase app.');
      return;
    }

    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(alert: true, badge: true, sound: true);

    try {
      token = await fcm.getToken();
      debugPrint('FCM token: $token');
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
    }

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onBackgroundMessage(_onBackground);
    fcm.onTokenRefresh.listen((t) => token = t);
    _fcmReady = true;
  }

  Future<void> _ensureChannels() async {
    if (_channelsReady) return;
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      try { await android.requestFullScreenIntentPermission(); } catch (_) {}
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _incomingChannelId,
        _incomingChannelName,
        description: 'Notifications for incoming VoIP calls',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
    }
    _channelsReady = true;
  }

  /// Shows a high-priority full-screen incoming call notification.
  Future<void> showIncomingCall({
    required String name,
    required String number,
  }) async {
    if (!_localReady) await init();
    await _ensureChannels();
    final android = AndroidNotificationDetails(
      _incomingChannelId,
      _incomingChannelName,
      channelDescription: 'Notifications for incoming VoIP calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'Incoming call',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await _local.show(
      incomingNotificationId,
      'Incoming call',
      name.isNotEmpty ? '$name • $number' : number,
      NotificationDetails(android: android, iOS: ios),
      payload: 'incoming_call',
    );
  }

  Future<void> cancelIncomingCall() async {
    try { await _local.cancel(incomingNotificationId); } catch (_) {}
  }

  Future<void> _onForeground(RemoteMessage msg) async {
    debugPrint('FCM foreground: ${msg.data}');
  }

  void _onTap(NotificationResponse r) {
    debugPrint('Notification tapped: ${r.payload}');
    if (r.payload == 'incoming_call') {
      final callback = _onIncomingCallTap;
      if (callback != null) {
        callback();
      } else {
        _pendingIncomingCallTap = true;
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage msg) async {
  debugPrint('FCM background: ${msg.data}');
}
