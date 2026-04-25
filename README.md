# Hub City Transit Flutter

Android-first Flutter migration of the Hub City Transit application.

## Local Development

1. Install Flutter SDK and Android SDK.
2. Run `flutter pub get`.
3. Run `flutter analyze` and `flutter test`.
4. Launch with `flutter run`.

## Runtime Configuration

Flutter should point at the same deployed Next.js host used by the web app.
It consumes the web app's `/api/*` endpoints; it does not call ArcGIS or Google
Directions directly.

Preferred:

```bash
flutter run --dart-define=NEXT_PUBLIC_SITE_URL=https://your-official-web-host
```

Optional override:

```bash
flutter run --dart-define=HCT_BASE_API_URL=https://your-official-web-host
```

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
flutter build appbundle --release --dart-define=NEXT_PUBLIC_SITE_URL=https://your-official-web-host
flutter build apk --release --dart-define=NEXT_PUBLIC_SITE_URL=https://your-official-web-host
```

## Production Readiness Checklist

1. `flutter analyze` passes with zero issues.
2. `flutter test` passes.
3. Build `appbundle` in release mode with upload key.
4. Verify location permissions and ETA behavior on real device.
5. Verify bus offline and API timeout behavior.
6. Run Play Console pre-launch report before rollout.
