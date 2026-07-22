# Cloud Calls Mobile

Production-grade cross-platform VoIP Softphone (Android + iOS) built with Flutter.

Comparable to Zoiper / Bria / Linphone / Grandstream Wave — designed with modern enterprise SaaS aesthetics.

## Stack

- **Flutter** 3.29+ / Dart 3.7+
- **JDK 17** for Android builds
- **Riverpod** 2.x — state management
- **sip_ua + flutter_webrtc** — SIP/WebRTC stack
- **flutter_callkit_incoming** — iOS CallKit + Android ConnectionService
- **Firebase Cloud Messaging** — push for incoming calls
- **Dio + Retrofit** — REST API layer (FreePBX/Asterisk REST)
- **Hive + flutter_secure_storage** — local storage
- **go_router** — navigation
- **Material 3** — design system (light + dark themes)

## Architecture (Clean Architecture)

```
lib/
├── core/              # constants, theme, network, errors, utils, services
├── data/              # models, datasources (remote/local), repository implementations
├── domain/            # entities, repository contracts, usecases
├── presentation/      # providers, screens, widgets
└── features/
    ├── sip/           # SIP UA wrapper, call manager
    ├── push/          # FCM handlers
    └── callkit/       # native call UI bridges
```

## Setup

```bash
flutter pub get
flutter run
```

On Windows, if Gradle cannot find Java 17, install Temurin JDK 17 or point `JAVA_HOME` to Android Studio's bundled JBR 17, then run `flutter clean && flutter pub get && flutter run` again. The Android project is already configured for Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20, automatic Java toolchain download, and core library desugaring required by `flutter_local_notifications`.

### Firebase

1. Create a Firebase project.
2. Add Android + iOS apps with package `com.awfar.cloudcalls`.
3. Drop `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`.
4. Enable Cloud Messaging.

### SIP / FreePBX

Edit `lib/core/constants/app_config.dart` and set your FreePBX server, port, transport (WSS recommended), and STUN/TURN.

### iOS extra

- Add `Microphone` + `VoIP` background modes in `Info.plist`.
- Add PushKit capability for CallKit incoming-call presentation.

### Android extra

- Add `RECORD_AUDIO`, `INTERNET`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `READ_PHONE_STATE`, `MANAGE_OWN_CALLS` in `AndroidManifest.xml`.
- Register `ConnectionService` for native call UI.

## Screens

Splash · Onboarding · Login (SIP + REST) · Home (Tabs) · Dialer · Active Call · Incoming Call · Call History · Contacts · Voicemail · Chat · Settings · Profile · About

## Themes

Light + Dark via `core/theme/app_theme.dart`. Material 3 dynamic color, premium glassmorphic accents.

## Logic ported from

`Awfar CallCenter` web project — same SIP behavior, registration flow, DTMF, hold/transfer, FreePBX REST contracts.
