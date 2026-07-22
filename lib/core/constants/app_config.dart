import '../services/backend_settings_service.dart';

/// Application configuration & FreePBX/SIP defaults.
/// Mirror of the web project's `environment.ts`.
class AppConfig {
  AppConfig._();

  static const String appName = 'Awfar CC';
  static const String appVersion = '1.0.0';

  // ---- Backend (FreePBX REST / Asterisk ARI bridge) ----
  /// Compile-time fallback when no URL is saved in app settings.
  static const String defaultApiBaseUrl = 'https://your-freepbx-domain.com/api';
  static String get apiBaseUrl => BackendSettingsService.instance.apiBaseUrl;

  static const String authPath = '/auth/login';
  static const String authRefreshPath = '/auth/refresh';
  static const String callsPath = '/voice/calls';
  static const String voicemailPath = '/voice/voicemail';
  static const String contactsPath = '/contacts';
  static const String agentsStatusPath = '/agents/status';
  static const String customersPath = '/customers';
  static const String tasksPath = '/tasks';
  static const String queuesPath = '/queues';
  static const String pushRegisterPath = '/push/register';
  static const String chatPath = '/chat/messages';
  static const String agentEventsPath = '/agent/events';
  static const String agentAssistPath = '/agent/assist';
  static const String recordingsPath = '/voice/recordings';
  static const String supervisorPath = '/supervisor';

  // ---- Webphone integration (web CRM → mobile softphone) ----
  static const String defaultIntegrationSendPath = '/integration/webphone/send';
  static const String defaultIntegrationCommandsPath = '/integration/commands';
  static String get integrationSendPath =>
      BackendSettingsService.instance.integrationSendPath;
  static String get integrationCommandsPath =>
      BackendSettingsService.instance.integrationCommandsPath;

  // ---- SIP defaults (override per-user at login) ----
  static const String sipServer = 'sip.your-freepbx-domain.com';
  static const int sipPort = 5060;
  static const String sipTransport = 'udp';
  static const String sipPath = '/ws';

  // ---- ICE servers ----
  static const List<Map<String, String>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    // {'urls': 'turn:turn.your-domain.com:3478', 'username': '...', 'credential': '...'},
  ];

  // ---- Timeouts ----
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration registerTimeout = Duration(seconds: 20);

  // ---- Features ----
  static const bool enablePushCalls = true;
  static const bool enableCallRecording = true;
  static const bool enableChat = true;
  static const bool enableAgentAssist = true;
  static const bool enableOfflineSync = true;
  static const int followUpReminderMinutes = 5;

  /// FreePBX default parking feature code (blind transfer target).
  static const String defaultParkingExtension = '*70';

  /// Keep false until foreground service is fully configured on device.
  static const bool enableBackgroundSip = false;

  /// True when a real backend API URL is configured (saved in app or build).
  static bool get hasBackendConfigured => BackendSettingsService.instance.isConfigured;
}
