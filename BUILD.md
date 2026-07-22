## Build Instructions

1. **Install Flutter** (>= 3.29): https://docs.flutter.dev/get-started/install
   - Android builds require **JDK 17**. This project also enables Gradle auto-download for Java 17 via Foojay, but installing JDK 17 locally is still recommended on Windows.
2. **Extract** this archive and `cd cloud_calls_mobile`
3. `flutter pub get`
4. Run on a device:
   - Android: `flutter run -d <device-id>`
   - iOS: `cd ios && pod install && cd .. && flutter run -d <device-id>`
5. Release builds:
   - Android: `flutter build apk --release` or `flutter build appbundle --release`
   - iOS: `flutter build ipa --release` (signing required)

## Configure your FreePBX

Edit `lib/core/constants/app_config.dart`:
- `apiBaseUrl` → your REST gateway URL
- `sipServer`, `sipPort`, `sipTransport`, `sipPath` → SIP/WSS endpoint
- ICE servers (STUN/TURN)

## Firebase

Drop `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`. Initialization is already wired in `lib/main.dart`.

## Windows Gradle file-lock fix (`flutter_webrtc`)

If `compileDebugJavaWithJavac` fails with **Unable to delete directory** under `build\flutter_webrtc\...`, a Gradle/Java process or Windows Defender is locking compiled `.class` files. This is **not** a Dart/code bug.

1. Stop any running `flutter run` (Ctrl+C in all terminals).
2. In Task Manager, end stray **java.exe** / **OpenJDK Platform binary** if Gradle is stuck.
3. Run from the project root:

```powershell
cd android
.\gradlew.bat --stop
cd ..

flutter clean
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

flutter pub get
flutter run
```

4. If it still fails, add the project folder to **Windows Security → Virus & threat protection → Exclusions**, then repeat step 3.
5. Last resort — single Gradle worker (slower but avoids races):

```powershell
$env:ORG_GRADLE_PROJECT_org_gradle_workers_max="1"
flutter run
```

The **Kotlin Gradle Plugin** warnings are future Flutter notices only; they did **not** cause this failure.

## Windows JDK 17 fix

If Gradle says `Cannot find a Java installation ... languageVersion=17`, install **Temurin JDK 17** or use Android Studio's bundled JBR 17, then set `JAVA_HOME` before running again:

```powershell
$env:JAVA_HOME="C:\\Program Files\\Eclipse Adoptium\\jdk-17"
$env:Path="$env:JAVA_HOME\\bin;$env:Path"
flutter clean
flutter pub get
flutter run
```

## Android desugaring fix

The `flutter_local_notifications` dependency requires Android core library desugaring. This is already enabled in `android/app/build.gradle` with:

```gradle
compileOptions {
    coreLibraryDesugaringEnabled true
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"
}
```

If you still see the same AAR metadata error, make sure you extracted and opened this latest package, then run `flutter clean`, `flutter pub get`, and `flutter run` from the project root, not from inside the `android` folder.

## What's included

- ✅ Clean Architecture (core / data / domain / presentation / features)
- ✅ Riverpod state management
- ✅ SIP UA + WebRTC (sip_ua + flutter_webrtc) wired to FreePBX
- ✅ FCM push + local notifications scaffolding
- ✅ CallKit / ConnectionService dependencies pre-declared
- ✅ Dio + interceptors for REST
- ✅ Secure storage for tokens & SIP password
- ✅ Light + Dark Material 3 themes
- ✅ Screens: Splash, Onboarding, Login, Home (5-tab), Dialer, Active Call, Incoming Call, History, Contacts, Voicemail, Chat, Settings, Profile, About
- ✅ Mock data for offline preview
- ✅ Android manifest with all VoIP permissions
- ✅ iOS Info.plist with VoIP / audio background modes

## Logic ported from web project

The SIP registration / call lifecycle / DTMF / hold / transfer behavior mirrors
the `useSIPPhone` hook from the **Awfar CallCenter** web project, adapted to
the Dart `sip_ua` package. REST contracts match `voiceFreePBXApi` /
`authApi` endpoints so the same FreePBX backend works without change.
