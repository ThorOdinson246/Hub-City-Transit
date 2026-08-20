# Security Guide

## What's Secret, What's Not

### Never commit to git:
| File | Reason |
|---|---|
| `.env` | Contains ArcGIS URL, API keys |
| `assets/data/stops.json` | Proprietary stop GPS data |
| `assets/data/schedules.json` | Proprietary route schedules |
| `assets/data/routes_wgs84.json` | Proprietary route polylines |
| `lib/stops.ts` (Next.js) | Same stop data on the web side |
| `lib/schedules.ts` (Next.js) | Same schedule data |
| `key.properties`, `*.jks`, `*.keystore` | Android signing credentials |

Both `.gitignore` files are already configured to exclude all of the above.

---

## Environment Variables

All sensitive config is loaded at startup from `.env` via `flutter_dotenv`.
The getters live in `lib/src/core/constants/app_constants.dart`:

```dart
String get arcGisUrl => dotenv.env['ARCGIS_URL'] ?? '';
String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
String get baseApiUrl => dotenv.env['HCT_BASE_API_URL'] ?? '';
```

**Never hardcode these.** If the ArcGIS URL leaks, anyone can scrape your live bus feed.

### `.env` format:
```
ARCGIS_URL=https://...
HCT_BASE_API_URL=https://...
GOOGLE_MAPS_API_KEY=...
```

### For CI/CD:
Store env values as repository secrets (GitHub Actions, Bitrise, etc.)
and inject them as a file at build time, e.g.:

```yaml
- name: Write .env
  run: echo "${{ secrets.ENV_FILE }}" > flutter_app/.env
```

---

## API Surface

### ArcGIS (live bus GPS)
- Called every 3 seconds via `busLocationPollingProvider`
- URL is env-controlled, not exposed in source
- Response includes: lat, lng, heading, timestamp, bus ID
- No auth token currently — the ArcGIS service must stay unauthenticated or
  you should add an API key rotation strategy

### Nominatim (address search)
- `https://nominatim.openstreetmap.org/search`
- No API key needed (OSM public endpoint)
- Rate-limited to 1 req/second — we debounce at 600ms so this is safe
- Add `User-Agent: hub-city-transit-app` header in `NominatimService` to stay
  compliant with OSM usage policy

### Local assets
- `stops.json`, `schedules.json`, `routes_wgs84.json` are bundled in the APK/IPA
- They're not accessible via HTTP — no server-side exposure risk
- But they ARE readable by anyone who decompiles the APK, so don't put
  anything in there you'd be embarrassed to have public

---

## Input Validation

- **Lat/lng from ArcGIS** — guarded against NaN before map moves (see `busLocValid` in `map_page.dart`)
- **Nominatim results** — typed via `NominatimPlace`, no dynamic JSON injection
- **User search query** — only used as a display string and passed to Nominatim, not eval'd
- **Schedule times** — parsed via `parseTimeToMinutes()` which returns `double.nan` on bad input,
  and those are explicitly skipped

---

## Android Security

- ProGuard/R8 is enabled in release builds (see `android/app/build.gradle`)
- Signing config lives in `key.properties` which is gitignored
- Do not store keystore passwords in `build.gradle` directly — use `key.properties`

### Recommended `AndroidManifest.xml` additions for production:
```xml
<!-- disable cleartext (HTTP) traffic -->
<application android:usesCleartextTraffic="false" ...>
```

If your ArcGIS URL is HTTPS (it should be), this is safe to enable.

---

## What's Safe to Open Source

The following can be on a public GitHub repo without concern:
- All Dart source under `lib/`
- `pubspec.yaml`
- `android/` and `ios/` config (minus signing keys)
- This docs folder

The following should stay private:
- `.env`
- `assets/data/*.json`
- Next.js `lib/stops.ts`, `lib/schedules.ts`, `lib/routes.ts`
- `docs/` folder (internal planning docs, this file)
- Signing keys

---

## Checklist Before Any Public Push

- [ ] `git status` — confirm `.env` not staged
- [ ] `git diff --cached assets/` — confirm no data files staged
- [ ] `flutter analyze` — no errors
- [ ] Grep for hardcoded URLs: `grep -r "arcgis.com\|api.hubcity" lib/`
- [ ] Grep for hardcoded keys: `grep -r "AIza\|Bearer\|token=" lib/`
