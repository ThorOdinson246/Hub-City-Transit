# Hub City Transit Flutter

Android-first Flutter migration of the Hub City Transit application.

## Local Development

1. Install Flutter SDK and Android SDK.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Launch with `flutter run`.

## Runtime Configuration

The Flutter app uses bundled route/stop/schedule data and reads live service envs directly.

```bash
flutter run --dart-define-from-file=env/dart_defines.json
```

If you prefer inline defines, pass `ARCGIS_URL` and `GOOGLE_MAPS_API_KEY` directly.

## Release Signing Setup (Play Store)

Create `android/key.properties` (do not commit):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=***
keyAlias=upload
keyPassword=***
```

If `key.properties` exists, release builds use that keystore.
If not present, release builds fall back to debug signing for local smoke tests only.

## Build Commands

```bash
flutter build appbundle --release --dart-define-from-file=env/dart_defines.json
flutter build apk --release --dart-define-from-file=env/dart_defines.json
```

## Production Readiness Checklist

1. `flutter analyze` passes with zero issues.
2. `flutter test` passes.
3. Build `appbundle` in release mode with upload key.
4. Verify location permissions and ETA behavior on real device.
5. Verify bus offline and API timeout behavior.
6. Run Play Console pre-launch report before rollout.
