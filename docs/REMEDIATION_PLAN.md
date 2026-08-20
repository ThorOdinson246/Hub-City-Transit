# Remediation Plan

Sequenced work derived from `AUDIT_2026-08-19.md`. Ordered by **dependency**, not purely by
severity — several high-severity items cannot be verified until earlier phases land.

Nothing here has been implemented. This is a proposal.

**Standing constraint:** no phase is complete until `flutter analyze` and `flutter test` are no
worse than the measured baseline (`analyze` 2 errors + 7 infos, `test` `+8 -1` — all of it in
`test/widget_test.dart` in the dirty working tree). Phase 0 gets that to zero.

---

## Phase 0 — Make the repo verifiable

The local tree analyses and tests fine; what does not work is a **fresh clone**, and the release
build has never been run. S0-3 and S0-4 remain readings of `build.gradle.kts` rather than observed
failures until 0-8 lands.

| # | Task | Exit criteria |
|---|---|---|
| 0-1 | ~~Install the Flutter SDK~~ **Void — it was already installed.** Flutter 3.41.9 at `~/flutter/bin`. Measured baseline: `analyze` → 2 errors + 7 infos (all in `test/widget_test.dart` in the dirty tree); `test` → `+8 -1`. | Done |
| 0-2 | Resolve the 4 uncommitted working-tree files. Two are regressions: the reverted `kIsWeb` User-Agent guard in `dio_provider.dart`, and the reintroduced `main_scaffold.dart` import in `widget_test.dart`. The other two (`app_theme.dart`, `schedule_page.dart`) need review — **confirm with the owner before touching**, another agent may hold this work. | Tree clean or consciously staged |
| 0-3 | Fix or delete `test/widget_test.dart`. It imports a deleted file, and even repaired it asserts on three string literals from its own scaffold while overriding the real router away. Recommend **delete and replace** (see 0-6). | `flutter test` compiles |
| 0-4 | Commit the Gradle wrapper: remove `gradle-wrapper.jar`, `gradlew`, `gradlew.bat` from `android/.gitignore`, `git add -f`, `chmod +x gradlew` | Present in `git ls-files` |
| 0-5 | Commit `analysis_options.yaml` (nothing in it is sensitive; excluding it means CI silently runs default lints) | Present in `git ls-files` |
| 0-6 | Decide the transit-data question. The three JSON files are gitignored as "proprietary" but ship inside every published artifact, so the secrecy already fails on its own terms. **Recommend: commit them** (326 KB, they are build inputs). Alternative: a `tool/fetch_data.sh` pulling from a private release asset. | `flutter build` succeeds on a fresh clone |
| 0-7 | Fix the parent-repo gitlink — add a real `.gitmodules` pointing at `Hub-City-Transit.git` and bump to current `main`, **or** merge `flutter_app` into the parent as a plain directory. The current half-state clones empty. | Parent clone yields source |
| 0-8 | `analyze` and `test` baselines are captured (see 0-1 and `CLAUDE.md` §7). **Still outstanding: `flutter build appbundle --release`** — never run, so S0-3 and S0-4 remain unverified readings. | A release build has been attempted and its output recorded |

| 0-9 | Add CI: `build_runner` → `analyze` → `test` on push. ~20 lines. Half the Definition of Done becomes self-enforcing, and "is it buildable from a clean clone" answers itself permanently. Prerequisite: 0-5. | Workflow green on a fresh runner |
| 0-10 | Fix the dead config in `analysis_options.yaml`: `implicit-casts`/`implicit-dynamic` were **removed in Dart 3** and are silently ignored, which is why 34 `dynamic` occurrences produce zero diagnostics. Replace with `language: strict-casts / strict-inference / strict-raw-types`. Land with a scoped `exclude:` and a tracked burn-down, not big-bang. | The lint config enforces what it appears to enforce |

**Note on ordering:** 0-9 depends on 0-4→0-7. Standing up CI before those just automates a
failing build.

---

## Phase 1 — Secrets and the server tier

The single decision that shapes everything else.

### The problem in one line

There is nowhere in the current architecture to keep a secret, and retiring the Next.js app
removes the last candidate.

### Recommendation

**Keep a thin API tier; delete Next.js and React entirely.** The honest framing is not "one piece
of non-Flutter infrastructure survives" — it is **"five TypeScript files survive; Next.js and React
do not."** You do not need a React framework to run four HTTP proxies.

Preferred host, in order:

1. **Cloudflare Pages + Workers (recommended).** `functions/api/*.ts` for the four proxies plus the
   announcements notify hook, with the Flutter web build deployed as the static site on the **same
   origin** — which makes the web CORS problem (W2) *vanish* rather than get papered over with
   headers. Secrets go in Worker bindings. Critically it fixes task 1-5 properly: Cloudflare has
   edge rate-limiting rules plus KV / Durable Objects for shared state, so no Upstash, no Redis, no
   extra vendor. Free tier covers a 7-route agency comfortably.
2. **Vercel without Next.js.** A plain `api/*.ts` functions directory alongside static output, no
   framework. Smallest migration — swap `NextRequest` for the standard `Request` and keep the
   handler bodies nearly verbatim. But you still need a third party for a real limiter, so it
   fixes less.
3. **Not Supabase.** Adopting Postgres + Auth + Storage to run four HTTP proxies is more platform,
   not less.

Either way Flutter remains the single *client* codebase, and the same origin should also serve
`announcements.json` — which retires the "where does content live" question in the announcements
design entirely.

This one move resolves five separate findings at once:

| Fixes | How |
|---|---|
| S0-1 key leak (Android **and** web) | Keys live server-side; the client ships none |
| W2 ETA broken on web | Your own endpoint sends CORS headers; Google's does not |
| S2-5 Nominatim ban risk | The server can set a compliant `User-Agent`, cache results, and queue to ≤1 req/s across all users |
| S2-1 ArcGIS load | One server-side cache serves N clients instead of N clients polling directly |
| "Money" rule in `CLAUDE.md` | A rate limit becomes enforceable |

### Tasks

| # | Task | Notes |
|---|---|---|
| 1-1 | **Rotate `GOOGLE_MAPS_API_KEY` and `ARCGIS_URL`** | Treat as compromised. Do this first and independently — it is not gated on any other work. |
| 1-2 | Remove `env.txt` from `pubspec.yaml` assets; drop `flutter_dotenv` | The asset is the leak vector |
| 1-3 | Move Directions, ArcGIS, and Nominatim behind `/api/*` | Client keeps only `HCT_BASE_API_URL`, which is not a secret |
| 1-4 | Set `HCT_BASE_API_URL` via `--dart-define-from-file` | `.vscode/tasks.json` already uses this mechanism. Note `env/dart_defines.json.example` is missing this key. |
| 1-5 | Replace the in-process rate limiter | `lib/rateLimit.ts` is a `Map` + `setInterval`. On Vercel's serverless runtime that is per-instance and effectively decorative. Needs shared state (Upstash/Redis) or a platform limiter. |
| 1-6 | Server-side response caching per endpoint | ArcGIS ~3s, Directions ~30s, Nominatim ~24h |

**Trade-off to state plainly:** this keeps ~5 TypeScript files alive against a stated goal of
consolidating everything into Flutter. The alternative — accepting public keys — is only survivable
with hard provider-side quotas and referrer restrictions, and Google Directions billing makes that
a bad bet. I recommend paying the cost, and note that option 1 above actually *reduces* moving
parts versus today by putting the web client and the API on one origin.

**If you reject this:** then Directions must be removed entirely (the ETA feature is already
unreachable dead code — S1-8 — so deleting it costs nothing today), Nominatim must be replaced
with a keyed geocoder that permits browser origins, and ArcGIS must be accepted as public. Say so
and I will plan that variant instead.

---

## Phase 2 — Play Store blockers

Independent of Phase 1 and can run in parallel.

| # | Task | Detail |
|---|---|---|
| 2-0 | **Enrol in Play App Signing, and back up the upload keystore offline.** ⚠️ **The only irreversible risk in this document.** `key.properties` and `*.jks` are gitignored and appear to exist on exactly one laptop. If that file is lost and you are not enrolled, the app **can never be updated** — new package name, every user must reinstall, install base and ratings gone. With Play App Signing, Google holds the app signing key, your keystore becomes only an *upload* key, and a lost upload key is recoverable via a Play Console reset. Also: encrypted offline backup of the `.jks` **and its passwords** in a password manager, with the location documented. | Enrolled; backup verified restorable |
| 2-1 | **Pin `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24`** | [API 36 required for new apps from 31 Aug 2026](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) — **12 days out**. Extension to 1 Nov available via Play Console. Also reconcile `flutter_launcher_icons: min_sdk_android: 21`. |
| 2-2 | Make missing `key.properties` **fail the release build** | Currently emits a debug-signed AAB and exits 0. Move `signingConfigs` out of `buildTypes` while you're there. |
| 2-3 | Real privacy policy + ToS | `web/privacy.html` exists and is decent — host it and link it. Currently both links point at the agency's marketing page. |
| 2-4 | Data Safety form | Precise location: collected, not shared, processed ephemerally. Must match the policy text. |
| 2-5 | Add `<uses-feature android:required="false">` for `location.gps` and `sensor.compass` | Play *implicitly* derives GPS as **required** from `ACCESS_FINE_LOCATION`, silently delisting the app on Wi-Fi tablets and ChromeOS |
| 2-6 | OSM + CARTO attribution via `RichAttributionWidget` | Licence compliance, not polish |
| 2-7 | Single source of version truth | `pubspec.yaml` → `package_info_plus`. Delete the three hardcoded strings. `versionCode` is currently stuck at 1, so the second Play upload would be rejected outright. |
| 2-8 | Add `-keep class io.flutter.plugins.** { *; }` | Real gap. Current rules survive only because `GeneratedPluginRegistrant` constructs plugins directly. Also drop `-keep class **.g.** { *; }` — it is a Java pattern that cannot match Dart's AOT-compiled generated code, and gives false confidence. |
| 2-9 | `--obfuscate --split-debug-info` + `ndk { debugSymbolLevel = "FULL" }` | Play warns on every upload without symbols; native crashes are otherwise unsymbolicated |
| 2-10 | Fix `mailto:` — add a `<queries>` intent entry | "Contact Support" is silently inert on Android 11+ |

---

## Phase 2b — Release process and operations

Absent from the first draft of this plan entirely. It is a thorough *code* remediation plan and was
silent on *operating* the thing.

| # | Task | Why |
|---|---|---|
| 2b-1 | **Staged rollout + internal testing track** before any production release | Play does not let you un-publish a bad release. Halting a staged rollout **is** the rollback mechanism — there is no other one. Going straight to 100% with a first-ever release-signed, R8-minified, obfuscated build, when task 2-8 already says the ProGuard rules are wrong, is how you find out at full blast. |
| 2b-2 | Run Play's **pre-launch report** | Free automated device testing; would catch a chunk of Phase 5 without writing a test |
| 2b-3 | **Crash reporting** — none exists (`grep -i "sentry\|crashlytics"` over `lib/` → nothing) | Task 2-9 produces obfuscation symbol files; without crash reporting *and* a place those symbols are archived per release, every release stack trace is permanently unreadable |
| 2b-4 | **Archive `--split-debug-info` output per release**, keyed by versionCode | Symbols and binary must match or the symbolication is worthless |
| 2b-5 | Decide `AnalyticsService`: implement or delete | `ConsoleAnalyticsService` is a `debugPrint` that is a **no-op in release**, wired as `analyticsProvider`. It reads to a future maintainer as working telemetry. It is not in the Phase 7 dead-code list. Any real SDK is another Data Safety declaration. |
| 2b-6 | **Monitoring on the API tier** | Once Phase 1 puts your server between every rider and the bus positions, you are the single point of failure — and you will currently learn about it by phone call. Needs uptime checks per endpoint, alerting on 5xx rate and on upstream ArcGIS failure, and request-volume visibility (also the only way you would detect endpoint abuse). |
| 2b-7 | Written **release checklist** | analyze clean · tests green · `build_runner` run · release build succeeds · version bumped · symbols archived · Data Safety current · rollout % chosen |

---

## Phase 3 — Stop showing riders wrong information

The highest-value phase for actual users, and the one I would not ship without.

| # | Task | Detail |
|---|---|---|
| 3-1 | **Replace the ratio stop-mapping** with an explicit `scheduleStopIndex` on each stop record | S1-1. This is a **data-schema change — needs your sign-off.** It is the only correct fix; every alternative is another heuristic. |
| 3-2 | **Add a service calendar** to `schedules.json` | S1-2. Needs a `serviceDate` concept, weekday/Saturday/Sunday patterns, and a holiday exception list. Also a schema change. |
| 3-3 | Add an explicit **"no service"** result state | S1-2 and S4-5. Covers weekends, after-hours, and between-trips — currently all render as blank rows. Must say "service has ended today · first bus 6:00 AM". |
| 3-4 | Bind `adjust()` to a `busId` / trip assignment | S1-3. Two buses on a 30-min headway currently confuse the engine into a 30-minute delta that silently kills live mode. |
| 3-5 | Use the real `StopModel.stopId` | S1-4. One-line fix, user-facing misinformation. |
| 3-6 | Make the poll loop survive errors | S1-6. `try`/`catch` inside the generator, `autoDispose`, lifecycle gating, backoff. Surface the error instead of discarding it via `asData?`. |
| 3-7 | Implement the ghost marker the comment already promises | S1-5. Keep `_lastKnownBus` on successful emissions. |
| 3-8 | Wire the location permission flow | S1-7. Onboarding CTA must actually request; add rationale UI; handle `deniedForever` with an `openAppSettings()` fallback (iOS only ever prompts once). Route it through a provider, not a FAB callback. |
| 3-9 | Delete the dead ETA code, or rebuild it behind the proxy | S1-8. Do not revive it with the three-boolean state machine — one keyed `AsyncValue`. |
| 3-10 | Add a router `redirect` guard for onboarding | S1-9. Currently bypassable; `onboardingSeenProvider` is dead code while the key is duplicated as a string literal in three files. |
| 3-11 | Fix contrast-critical theme bugs | `outline`/`outlineVariant` collapse makes past and future stops identical (S1-9) |

| 3-12 | **Text-scale pass** (`textScaler: 2.0`) — 6 known overflow sites, including the Schedule tab's primary control | promoted from Phase 5 |
| 3-13 | **48dp touch targets** — stop markers are 18–28dp and are the map's main interaction | promoted from Phase 5 |
| 3-14 | **Contrast** — white-on-gold at 1.53:1 is a flat WCAG AA failure; light-mode borders at 1.29:1 | promoted from Phase 5 |
| 3-15 | **Error / empty / offline states** on every async surface; stop rendering raw exception text | promoted from Phase 5 |

**Sequencing note:** 3-1 and 3-2 are both schema changes. Do them together, in one migration,
with a version field on the payload — not as two separate breaking changes.

**Why accessibility moved up.** An earlier draft of this plan put all of it in Phase 5, below
server-cost optimisation. That was wrong on two counts.

*Legally:* Hub City Transit is a City of Hattiesburg service — an ADA **Title II** public entity —
and the DOJ's web/mobile rule explicitly covers mobile apps at WCAG 2.1 AA. Compliance dates were
extended in April 2026 to **26 Apr 2027** (population ≥50,000) and **26 Apr 2028** (under 50,000).
Hattiesburg sits near that line, so 2028 is the likely tier — but it is a *dated legal obligation*,
not polish.

*Practically:* the app's own fares list seniors 62+ and disabled riders as core segments. A
timetable that overflows at large text and a stop marker too small to hit are your two largest
rider groups being locked out. That is the same class of problem as a wrong arrival time, so it
belongs in the same phase. The remaining Phase 5 items (SafeArea, `PopScope`, web viewport) stay
where they are.

---

## Phase 4 — Cost and performance

| # | Task | Impact |
|---|---|---|
| 4-1 | `autoDispose` + `AppLifecycleState` gating on the poll | 1,200–2,400 req/hr/user → near zero when not looking at the map |
| 4-2 | Reconsider the 3s interval | With a server-side cache (1-6), client interval and upstream load decouple |
| 4-3 | Memoise polylines | Removes ~5.1M `LatLng` allocations/hour |
| 4-4 | Precompute the trip route slice once per trip | Removes ~15,000 trig calls per rebuild |
| 4-5 | Cache `getRoutes`; dedupe in-flight `_loadStops` | Stops 7× redundant startup parsing on the UI isolate |
| 4-6 | Bound the typewriter animation | Stops 20–33 `setState`/sec for the app's entire lifetime |
| 4-7 | Move transfer-map computation out of the keystroke path | Currently recomputed on every character typed |
| 4-8 | Add `CancellableNetworkTileProvider` for web | Requires a dependency — **ask first** |

---

## Phase 5 — Accessibility and UX

| # | Task |
|---|---|
| 5-1 | Text-scale pass at `textScaler: 2.0` — 6 known overflow sites, including the Schedule tab's primary control |
| 5-2 | 48dp touch targets — stop markers (currently 18–28dp) are the priority; they are the page's main interaction |
| 5-3 | Contrast pass — derive foreground from background luminance instead of hardcoding `Colors.white` (gold is 1.5:1); fix light-mode borders at 1.4:1 |
| 5-4 | Semantic labels — search field, theme pills, progress indicator, page view, back buttons |
| 5-5 | Replace hardcoded FAB offsets with measured geometry |
| 5-6 | Error / empty / offline states on every async surface; stop rendering raw exception text |
| 5-7 | `SafeArea` at the shell; remove hardcoded insets |
| 5-8 | `PopScope` for sheet dismissal; on-screen back everywhere; router `errorBuilder` |
| 5-9 | Web: viewport meta tag, fix the SVG namespace typo |

---

## Phase 6 — Announcements

Design: `ANNOUNCEMENTS_DESIGN.md`. **Bring the design back for approval before building.**

**This phase is split, because "your feature is seventh of eight" is both bad communication and
partly wrong.** Announcements steps 1–2 (schema + static endpoint + bundled empty fallback) have
**no dependency on Phase 1 at all** if the document is served as a static CDN asset. Publish those
during Phase 1 and the content pipeline exists before the client does — near-zero cost, and it
unblocks the agency side immediately.

| Announcements step | Lands in |
|---|---|
| 1–2 · schema, static endpoint, bundled fallback | **Phase 1** (parallel, no dependency) |
| 3 · typed preferences layer (`AUDIT` S4-8) | right after Phase 3 |
| 4–5 · inbox, unread state, critical banner | right after Phase 3 — **this is where the feature ships** |
| 6 · FCM, channels, permission flow, opt-outs | late, and only after re-deciding (see below) |
| 7 · iOS APNs | when `ios/` exists |

Steps 3–5 do depend on Phase 1's cache-first repository pattern and on the typed preferences layer;
building them first means writing the fetch/cache/fallback logic twice.

**One caveat on deferring push:** adding FCM changes the Data Safety declaration, and a Data Safety
change *after* launch triggers re-review and can hold a release. If push is wanted at all, decide
before first submission rather than at step 6.

Prerequisite from this plan: a **typed preferences layer** (S4-8). The current one-`StateNotifier`-
per-toggle pattern does not survive N notification channels, and it has a live lost-write race.

---

## Phase 7 — Structural debt

Deliberately last. None of it is user-visible; all of it makes later work cheaper. Do it
incrementally, behind tests, not as a big-bang refactor.

| # | Task |
|---|---|
| 7-1 | Decompose `map_page_stop_sheet.dart` (1,395 lines) and `map_page.dart` (845, with a 545-line `build()`). They are `part` files of one library, so extraction is mechanical but touches everything. Biggest win: the 3s poll would rebuild only the bus marker, not the polylines and search filter. |
| 7-2 | Fix the layering inversion — domain must not import `data/`; `core/constants` must not import Flutter |
| 7-3 | Make routes data-driven — remove the four places a route must be registered; replace force-unwrapped map lookups with exhaustive switches so a missing entry is a compile error |
| 7-4 | Move bundled JSON to cache-first remote so schedule changes stop requiring a store release |
| 7-5 | Inject seams: `AssetBundle`, `DateTime.now()`, `NominatimService`, `SharedPreferences` |
| 7-6 | Delete 5 unused dependencies, dead providers/parameters/branches, and the filler comments |
| 7-7 | Replace stringly-typed `EtaResultModel.status` with a sealed union |
| 7-8 | Key stop matching on `stopId` instead of bidirectional substring |
| 7-9 | Plan the `flutter_riverpod` 2→3 and `go_router` 16→17 migrations |
| 7-10 | Replace or vendor `flutter_compass` (21 months stale, single maintainer, no web) |
| 7-11 | Docs: rewrite `ARCHITECTURE.md`, `SECURITY.md`, `README.md`; delete the other five; un-ignore `docs/` |

---

## Test coverage to add

Current state: 3 meaningful unit tests, 1 broken widget test, no golden tests, no
`integration_test/`.

Highest-value tests that do not exist, in order:

1. **The launch → onboarding/map decision**, over `SharedPreferences.setMockInitialValues`, in
   both directions plus the "completing onboarding writes the flag" path. Every user traverses it
   exactly once, it is currently guarded by a bare `Timer` and two uncaught `await`s, and it is
   precisely what will regress when the `redirect` guard (3-10) lands.
2. **`SchedulePage` at `textScaler: 2.0`**, asserting no `RenderFlex` overflow. Catches S3-1 today.
3. **The schedule delta engine against a known timetable** — on-time, late, between-trips, wrong
   service day. This is the code that lies to riders; it deserves the most tests.
4. **Malformed-JSON resilience** — one bad record must not take out a route.
5. **Poll-loop error recovery** — one failure must not permanently kill the stream.

---

## Suggested order if you want the shortest path to submittable

1. Phase 0 (verifiability) — nothing is real until this lands
2. 1-1 (rotate keys) — independent, do it today
3. Phase 2 (Play blockers) — **2-1 is on a 12-day clock**
4. Phase 1 remainder (server tier)
5. Phase 3 (rider truth)
6. Phases 4–5
7. Phase 6 (announcements)
8. Phase 7 (debt)

Phases 4, 5, and 7 are genuinely deferrable past a first submission. Phase 3 is not — an app that
confidently shows a rider a wrong arrival time under a LIVE badge is worse than one that shows a
static timetable.
