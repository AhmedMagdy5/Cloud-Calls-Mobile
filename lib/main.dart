import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'domain/entities/call_entity.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'core/router/app_router.dart';
import 'features/sip/sip_service.dart';
import 'features/callkit/callkit_service.dart';
import 'features/push/push_service.dart';
import 'features/background/sip_background_service.dart';
import 'features/share/share_intent_handler.dart';
import 'features/integration/webphone_integration_service.dart';
import 'features/presence/mobile_presence_service.dart';
import 'features/sip/headset_controls.dart';
import 'core/services/follow_up_notification_service.dart';
import 'data/call_history_store.dart';
import 'data/parked_call_store.dart';
import 'data/sync/offline_sync_queue.dart';
import 'features/agent_events/agent_events_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hive local storage
  await Hive.initFlutter();

  // Storage
  await StorageService.init();
  await OfflineSyncQueue.instance.purgeIfNoBackend();
  SipService.instance.loadPresence();

  // Local call notifications must work even when Firebase isn't configured.
  await NotificationService.instance.init();
  await CallKitService.instance.init();
  await FollowUpNotificationService.instance.init();
  await SipBackgroundService.instance.init();
  await CallHistoryStore.instance.load();
  await ParkedCallStore.instance.load();
  AgentEventsService.instance.start();

  // Firebase is optional during dev
  // when a default Firebase app exists.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.instance.init();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  runApp(const ProviderScope(child: CloudCallsApp()));
}

class CloudCallsApp extends ConsumerStatefulWidget {
  const CloudCallsApp({super.key});

  @override
  ConsumerState<CloudCallsApp> createState() => _CloudCallsAppState();
}

class _CloudCallsAppState extends ConsumerState<CloudCallsApp>
    with WidgetsBindingObserver {
  GoRouter? _router;
  String? _shownIncomingCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SipService.instance.addListener(_onSipChange);
    NotificationService.instance.onIncomingCallTap = () => _onSipChange(force: true);
    unawaited(HeadsetControls.instance.init());
    HeadsetControls.instance.onDeviceChange = () => SipService.instance.refreshHeadsetState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initShareHandler();
      _initWebphoneIntegration();
    });
  }

  void _initWebphoneIntegration() {
    WebphoneIntegrationService.instance.onRemoteDial = (number, {required bool autoDial}) {
      final router = _router;
      if (router == null) return;
      if (autoDial) {
        if (SipService.instance.presence == PresenceMode.offline) {
          ref.read(dialerPrefillProvider.notifier).state = number;
          router.go('/dialer');
          return;
        }
        router.push('/call/active');
        unawaited(SipService.instance.makeCall(number));
      } else {
        ref.read(dialerPrefillProvider.notifier).state = number;
        router.go('/dialer');
      }
    };
  }

  void _initShareHandler() {
    ShareIntentHandler.instance.onShareDial = (number, autoDial) {
      final router = _router;
      if (router == null) return;
      if (autoDial) {
        if (SipService.instance.presence == PresenceMode.offline) {
          ref.read(dialerPrefillProvider.notifier).state = number;
          router.go('/dialer');
          return;
        }
        router.push('/call/active');
        unawaited(SipService.instance.makeCall(number));
      } else {
        ref.read(dialerPrefillProvider.notifier).state = number;
        router.go('/dialer');
      }
    };
    unawaited(ShareIntentHandler.instance.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SipService.instance.removeListener(_onSipChange);
    NotificationService.instance.onIncomingCallTap = null;
    ShareIntentHandler.instance.dispose();
    unawaited(MobilePresenceService.instance.stop(logout: true));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(MobilePresenceService.instance.stop(logout: true));
    }
    if (state == AppLifecycleState.resumed) {
      // Only verify SIP if we're not already registered — avoids tearing down
      // a healthy session and bouncing into "Reconnecting…" on every resume.
      final s = SipService.instance.status;
      if (s != SipStatus.registered &&
          s != SipStatus.registering &&
          s != SipStatus.reconnecting) {
        SipService.instance.ensureConnected();
      }
      if (AppConfig.hasBackendConfigured) {
        OfflineSyncQueue.instance.flush();
      }
      FollowUpNotificationService.instance.checkDue();
      unawaited(MobilePresenceService.instance.ensureRunning());
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSipChange(force: true));
    }
  }

  /// Global incoming-call router — works no matter which screen is on top.
  void _onSipChange({bool force = false}) {
    final router = _router;
    if (router == null) return;
    final sip = SipService.instance;
    final call = sip.activeCall;
    final loc = router.routerDelegate.currentConfiguration.uri.toString();

    if (sip.openActiveAfterHeldResume && call != null && !call.status.isTerminal) {
      sip.consumeOpenActiveAfterHeldResume();
      if (loc != '/call/active' && loc != '/call/incoming') {
        router.push('/call/active');
      }
    }

    final onIncomingRoute = loc == '/call/incoming';

    if (call == null) {
      _shownIncomingCallId = null;
      if (onIncomingRoute && router.canPop()) {
        router.pop();
      }
      return;
    }

    final isIncomingRinging = call.direction == CallDirection.incoming &&
        call.answeredAt == null &&
        (call.status == CallStatus.ringing ||
            call.status == CallStatus.connecting);

    final isMissedIncoming = call.direction == CallDirection.incoming &&
        call.answeredAt == null &&
        call.status.isTerminal;

    if (isMissedIncoming) {
      _shownIncomingCallId = null;
      if (onIncomingRoute && router.canPop()) {
        router.pop();
      }
      return;
    }

    if (isIncomingRinging && (force || _shownIncomingCallId != call.id)) {
      _shownIncomingCallId = call.id;
      if (loc != '/call/incoming' && loc != '/call/active') {
        router.push('/call/incoming');
      }
    }
    if (call.status.isTerminal) {
      if (_shownIncomingCallId == call.id) _shownIncomingCallId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme follows user preference (light / dark / system).
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);
    _router = router;

    return MaterialApp.router(
      title: 'Awfar CC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}


