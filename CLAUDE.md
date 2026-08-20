# CLAUDE.md — Hub City Transit (Flutter)

> Enforcement note: there is no CI workflow and no git hook in either repo yet, so every rule
> below is honour-system until `docs/REMEDIATION_PLAN.md` 0-9 lands.

Operating rules for any human or agent working in this repository. Read this before writing code.

---

## 1. What this is

A real-time bus tracking app for Hub City Transit, Hattiesburg MS. Live GPS positions,
stop-by-stop schedules, ETAs, fares, and walk+ride trip planning.

**Seven routes**, not two: `blue`, `gold`, `green`, `brown`, `orange`, `red`, `purple`.
**Nine bus IDs**: `blue1`, `blue2`, `gold1`, `gold2`, `green`, `brown`, `orange`, `red`, `purple`.
Older handover docs say "2 routes" — they are wrong. Verify against
`lib/src/core/constants/transit_ids.dart` and `assets/data/stops.json`, never against prose.

Targets: **Android** (Play Store, imminent), **Web** (replacing the retired Next.js client),
**iOS** (planned; no `ios/` directory exists yet).

### The two repositories

`flutter_app/` is its own git repository nested inside the `hubcitytransit` repo. There is no
`.gitmodules`; the parent tracks it as a bare gitlink pinned to a stale commit. **Always run
`git rev-parse --show-toplevel` before committing.** App code commits belong in `flutter_app/`.

The root Next.js app is **legacy and unmaintained**. Do not port business logic *from* it or
treat it as the source of truth. Its `/api/*` route handlers are the exception — see §4.

---

## 2. Hard rules

These are not preferences. Violating one is a defect regardless of whether anything breaks.

### Secrets

- **Never read, print, echo, cat, grep, or paste the contents of** `env.txt`, `key.properties`,
  `*.jks`, `.env`, or `env/dart_defines.json`. You may reference their existence and their
  *key names*. You may run `git check-ignore` against them. Nothing else.
- **Never commit** any of the above. Verify with `git check-ignore -v <path>` before staging
  anything in the same directory.
- **Never add a secret to a Flutter asset, a `--dart-define`, or any file that ships in the
  bundle.** All three are extractable. On web, a declared asset is served at a public URL.
  A value is only secret if it lives on a server you control.
- If you believe a key has been exposed, say so immediately and recommend rotation. Do not
  quietly work around it.

### Money

Any code path that can issue a billed or rate-limited request (Google Directions, Nominatim
geocoding, ArcGIS) must have, before it merges:

1. A server-side proxy holding the credential — never a client-side key.
2. A rate limit enforced **on the server**. A client-side limiter protects nothing; the
   attacker controls the client.
3. A cache with an explicit TTL.
4. A bounded worst case you have actually counted. State the number in the PR description:
   "one tap = N requests."

### Writing files

Do not create, edit, or delete anything outside the scope you were given. Another agent may be
working in this tree concurrently. When the instruction is "read and propose", propose in
markdown — do not write code "to show what you mean".

### Git

- Do not commit or push unless explicitly asked.
- If asked while on `main`, **branch first**.
- Subject line: imperative mood, **≤100 characters**, Conventional Commits prefix
  (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `build(android):`, `refactor:`, `perf:`).
- No `checkpoint:`, no `wip`, no empty subjects, no typo'd subjects. If a change is not worth a
  real message it is not worth a commit.
- Body explains **why**, not what. The diff already says what.
- One logical change per commit.
- Do not back-date commits. The existing history was back-dated via `GIT_AUTHOR_DATE`
  (see `docs/GIT_MILESTONE_MAPPING.md`); do not extend that practice. If this repo is ever
  shown to a third party as a work record, synthetic dates are a misrepresentation.

### Context that outlives the session

Anything important — a decision, a trade-off taken, a constraint discovered, a deferred fix —
goes into **`docs/DECISIONS.md`**, newest entry at the top, formatted `## YYYY-MM-DD — <decision>`.
One append-only file, not a new file per session. Not a code comment, not a commit body only, and
not left in the conversation.

`docs/` is committed as of 2026-08-19, so this store is durable. Keep it that way.

---

## 3. Architecture

```
UI (features/*/presentation)
  └─> Riverpod provider (app/providers.dart, or feature-local)
        └─> TransitRepository            (domain/repositories — the interface)
              └─> TransitRepositoryImpl  (data/repositories)
                    └─> Dio  |  bundled JSON asset  |  SharedPreferences
```

**Invariants. Breaking one of these is a review rejection, not a discussion.**

1. **UI never calls Dio, `rootBundle`, `SharedPreferences`, `Geolocator`, or an HTTP service
   directly.** It goes through a provider. Today `NominatimService` is constructed inside widget
   state in two places and `Geolocator.requestPermission()` is called from a FAB callback —
   both are existing violations to be fixed, not precedents to copy.
2. **The domain layer imports no Flutter.** No `material.dart`, no `Color`, no widgets. Today
   `domain/repositories/transit_repository.dart` imports models from `data/`, and
   `core/constants/route_metadata.dart` imports `material.dart` for `Color`. Both are wrong
   and are on the remediation list.
3. **Feature-first folders.** A feature owns its widgets, controllers, and state. Cross-cutting
   state only goes in `app/providers.dart` when two features genuinely share it.
4. **Models are `freezed` + `json_serializable`.** Never hand-edit `*.freezed.dart` / `*.g.dart`.
   After touching a model, run:
   `dart run build_runner build --delete-conflicting-outputs`
5. **Generated code is gitignored**, so `build_runner` is mandatory before analyze/test/build on
   any fresh checkout. Note the trap this creates: the generated files are present-but-untracked
   on *this* machine, so a local verify can pass for code that has never once built from a clean
   tree. The Definition of Done is evaluated **on this machine** until `REMEDIATION_PLAN.md` 0-6
   and 0-9 land. Do not claim clean-clone reproducibility before then.

### State

Riverpod 2.x (`flutter_riverpod`). Providers are the DI container.

- Prefer `autoDispose` for anything holding a subscription, a timer, or a poll loop. The current
  `busLocationPollingProvider` is not `autoDispose` and never stops — do not copy it.
- Never put an unguarded `while (true)` in an `async*` provider. An exception inside the
  generator terminates the stream permanently for the app's lifetime.
- Injected time: pass `now` as a parameter. `ScheduleAdjustmentUseCase.adjust()` does this
  correctly and is the model to follow. Providers that call `DateTime.now()` internally are
  untestable.

### Routing

`go_router` with `StatefulShellRoute.indexedStack`. Tabs are **Map / Schedule / Settings**.
`/launch`, `/onboarding`, `/about` sit outside the shell. IndexedStack is deliberate — it keeps
map camera and selected stop alive across tabs. **Ask before changing the tab structure.**

Every route needs an on-screen back affordance. Never rely on the Android hardware back button;
iOS does not have one. `context.canPop() ? context.pop() : context.go('/fallback')` — an
unconditional `pop()` is a dead button when the route is the initial location.

---

## 4. Platform strategy (Android + Web + iOS)

**No `Platform.isAndroid` / `Platform.isIOS` branches in feature code.** Anything platform-specific
goes behind an interface in `core/` with per-platform implementations selected by a provider.
`kIsWeb` guards are tolerated at the *provider* boundary only (as in `compassProvider`), never
scattered through widgets.

Before adding any dependency, check **iOS and Web support** and state the finding in your
proposal. Current known gaps:

| Constraint | Consequence |
|---|---|
| Browsers forbid setting `User-Agent` | Nominatim's required identifying header is impossible on web. Needs a proxy. |
| Google Directions Web Service sends no CORS headers | The entire ETA path fails for 100% of web users if called client-side. |
| Flutter Web assets are public URLs | `assets/env.txt` would be world-readable. Never bundle a secret. |
| `flutter_compass` is android+ios only | Heading cone silently absent on web. |
| Flutter Web renders to canvas | No crawlable DOM, no SEO. Decide deliberately. |

**Consequence: a server tier is the only place a secret can live**, the only place a
`User-Agent` can be set, and the only place a rate limit means anything. Where that tier ends up
hosted is **undecided and owned by the web workstream**, not by this repo. Until it exists:

- Do not add a new client-side call to any keyed or billed API.
- Write new remote data sources against an **injected base URL**, never a hardcoded host, so
  repointing them is configuration.

Document any new native config (manifest entry, gradle change, entitlement) in `docs/`, with the
iOS equivalent noted, even before `ios/` exists.

---

## 5. Code conventions

**Precedence, stated once and globally:** every rule in this document is a **new-code rule**
unless it says otherwise. New and modified lines must satisfy it. Untouched lines stay as they
are — do not opportunistically "fix" them. **Where these rules and "match the surrounding code"
conflict, these rules win.**

This matters because the codebase is full of what follows. Silence about a violation does not
mean the code is clean:

| Rule | Existing violations at baseline |
|---|---|
| No `dynamic` in signatures | **34** (e.g. `map_page.dart:231` `dynamic userPos`) |
| No `!` on subscripts | **23** (`about_page.dart:94-96`, `schedule_page.dart:31,78,88,323`, …) |
| `kIsWeb` at provider boundary only | **5** — `providers.dart:25` is the legitimate one; `nominatim_service.dart:30`, `map_page.dart:51`, `settings_page.dart:138,163` are not |
| UI must not call platform APIs directly | **4** (`map_page.dart:738`, `settings_page.dart:146,154`, `launch_page.dart:45`) |

**Match the surrounding code** applies to everything the rules don't cover — naming, formatting,
file organisation, widget composition. If you think an existing pattern is wrong, write the
argument to `docs/DECISIONS.md`, keep the existing pattern in the code, and raise it in your
report. Do not unilaterally introduce a second pattern.

### Comments

Write comments that explain **why**. Delete comments that restate the code.

```dart
// Bad — restates the line below it.
// Skip button
TextButton(onPressed: _skip, child: const Text('Skip')),

// Good — explains a non-obvious constraint.
// flutter_map emits no MoveEnd for programmatic moves, so the gesture timer
// that restores the header never fires on a camera fly-to.
```

Banned outright: section-label comments (`// Logo`, `// Hero`, `// Page title`), comments
describing behaviour that cannot occur, dartdoc referencing deleted classes, and any comment
that would read as filler to a reviewer.

`TODO` is not a deliverable. Either fix it or write it into `docs/` as tracked work.

### Types

- No `dynamic` in signatures. `List<dynamic>` holding a known type is a compile error converted
  into a runtime one.
- No stringly-typed state machines. `EtaResultModel.status` is a bare `String` with four magic
  literals — that is the anti-pattern, not the pattern.
- No `!` on map lookups. `routeColors[route]!` crashes at runtime when a `RouteId` is added
  without a colour. Use exhaustive switches so the compiler catches it.
- No bare `catch (e) { return []; }`. A network failure and an empty result set must be
  distinguishable by the caller and by the user.

### UI

Errors, empty states, offline states, and permission-denied states are **first-class UI**, not
afterthoughts. Every async surface needs all four. `asData?.value ?? []` silently swallowing an
error is a defect.

Accessibility is not optional:
- Semantic labels on every interactive element.
- **48dp minimum touch targets.** Stop markers are currently 18–28dp; that is a bug.
- Must survive `textScaler: 2.0` without overflow. Fixed-height boxes containing scalable text
  are the usual cause.
- Contrast ≥4.5:1 for text in **both** themes. Never hardcode `Colors.white` on a route colour —
  gold (`#F5CE0A`) gives ~1.5:1.
- Never convey state by colour alone.

Never render raw exception text to the user — `'Stops error: $e'` leaks the request path.

---

## 6. Data & scalability

Adding a route, a stop, a schedule change, or an agency must be a **data change, not a code
change**. Today it is not: `RouteId`/`BusId` are compile-time enums, `route_metadata.dart` holds
three hand-maintained maps, `transfer_connections.dart` hardcodes 43 keyed pairs, and the ArcGIS query
string embeds the operator (`'hct ${busId}'`). Treat every one of those as a thing to remove, and
do not add a fourth place where a route must be registered.

Bundled JSON is the **offline fallback**, not the source of truth. The target is cache-first
remote: fetch, validate, cache, fall back to the bundled asset. Schedule updates must not require
a store release.

Parsing must be defensive. One malformed record currently takes out an entire route, because
`fromJson` is mapped over a list with no per-record guard. Validate coordinates in the repository
(`GeoUtils.isValidLatLng` is currently only called from presentation code).

---

## 7. Definition of done

A change is done when **all** of these hold. Report real output; if something fails, say so.

- [ ] `dart run build_runner build --delete-conflicting-outputs` — **always, before analyze.**
      Generated code is gitignored, so on a fresh checkout nothing compiles without it. If you
      did not run it, you did not verify anything.
- [ ] `flutter analyze` — no worse than baseline (see below). 0 new errors, 0 new warnings,
      no new infos.
- [ ] `flutter test` — no worse than baseline
- [ ] `flutter build appbundle --release` — succeeds, if the change touches build config,
      dependencies, or anything R8 could strip. Debug builds prove nothing about release.
- [ ] New behaviour has a test. Bug fixes have a regression test that fails without the fix.
- [ ] No new `dynamic`, no new `!` on a map lookup, no new bare `catch`.
- [ ] Error/empty/offline states handled.
- [ ] Works at `textScaler: 2.0`.
- [ ] No secret added to any bundled artifact.
- [ ] Context worth keeping written to `docs/`.

### Measured baseline

Flutter 3.41.9 (`~/flutter/bin/flutter`, not on the default `PATH` in every shell — export it).
Measured at HEAD `4a964ce` on 2026-08-19:

```
flutter analyze → 3 issues, 0 errors, 0 warnings
                  3 infos, all prefer_const_* in schedule_page.dart (131, 131, 309)
flutter test    → +9   All tests passed
```

**Your change must not increase either number.** Paste the final summary line of each command
verbatim in your report — not a paraphrase, not "looks clean".

`flutter build appbundle --release` has still not been verified end to end. Note that
`flutter_native_splash` was removed from `pubspec.yaml` because Flutter registers it in
`GeneratedPluginRegistrant` while excluding dev-dependency plugins from the release classpath,
which broke the release build. Expect more of that class of problem on the first real run.

This baseline was produced with generated code already present locally. On a fresh checkout
`build_runner` must run first or nothing compiles.

---

## 7b. Situations the rules above don't cover

| Situation | Rule |
|---|---|
| **Branch naming** | `feat/<slug>`, `fix/<slug>`, `chore/<slug>`. The repo currently has four conventions; pick these. |
| **A test was already failing** | Report it as pre-existing with the baseline numbers. Do not tick the box on faith, and do not delete the file to go green. If your diff takes `-1` to `-2`, that one is yours. |
| **Merge conflict in `*.g.dart` / `*.freezed.dart`** | Never resolve by hand. Take either side, then re-run `build_runner`. |
| **Dependency versions** | `pubspec.lock` is committed and authoritative. Never run `flutter pub upgrade` unprompted. New deps pin with `^` and require the iOS/Web support finding from §4. |
| **Logging** | There is no logging story: `logger` is a declared dependency with zero imports and `avoid_print` is on. Until that is resolved, use `debugPrint` guarded by `kReleaseMode`. Do not adopt `logger` in one file and leave the rest. |
| **Another agent is in the same file** | Announce which files you will edit before editing. Never `git checkout --` or `git stash` a file you did not modify. On conflict, stop and report — do not resolve someone else's work. `map_page.dart` and `map_page_stop_sheet.dart` are the hot spots. |
| **"Ask before X" but nobody is available** | Do not do it. Stop, write the question *and your recommended answer* into your report, and complete the largest part of the task that doesn't depend on the answer. |
| **Diff size** | Soft cap ~400 changed lines. Split above it. |
| **`BuildContext` across an `await`** | `use_build_context_synchronously` is already on via `flutter_lints`. Guard with `if (!mounted) return;`. |

---

## 8. Known traps

Live defects. Do not copy these patterns; do not be surprised by them.

| Trap | Where |
|---|---|
| **`GOOGLE_MAPS_API_KEY` ships inside the bundle** — public URL on web. Rotate + proxy. | `pubspec.yaml:46` → `main.dart:10` → `app_constants.dart:15` |
| Release build silently falls back to **debug signing** | `android/app/build.gradle.kts` |
| `targetSdk`/`minSdk`/`compileSdk` unpinned — depend on the dev's local SDK | same file |
| GPS→schedule stop mapping is a ratio between non-corresponding lists | `schedule_adjustment_use_case.dart:259` |
| No service calendar — Sunday shows weekday times as LIVE | no code exists |
| Delta engine takes no `busId`; can pick the wrong bus's trip | `schedule_adjustment_use_case.dart:58` |
| Fabricated stop IDs shown to riders (`8120 + index`) | `schedule_page.dart:316` |
| Poll loop dies permanently on one network error | `providers.dart:71-81` |
| Map rebuilds ~4,286 `LatLng` every 3s, forever, even when backgrounded | `map_page.dart:358` |
| ETA feature is unreachable dead code | `map_page_stop_sheet.dart` — params declared, never read |
| Onboarding "Enable Location" never requests permission | `onboarding_page.dart:435` |
| Privacy Policy and ToS point at the same third-party marketing page | `settings_page.dart:186,195` |
| No OSM/CARTO attribution anywhere — licence breach | `map_page.dart:495` |
| Repo is not buildable from a clean clone | `assets/data/*.json`, `env.txt`, `gradlew` still gitignored |

Line references above are **±5 lines** — these files are under active edit. Locate by symbol
name, not line number.

Full detail with reproduction steps: `docs/AUDIT_2026-08-19.md`.
Sequenced fixes: `docs/REMEDIATION_PLAN.md`.

---

## 9. Working with the human

- Tell them plainly when something they asked for is a bad idea, then build the version you
  agree on. Do not silently substitute your own judgement.
- **Ask before**: adding a dependency, changing the tab structure, or altering the data schema.
- Name the trade-off before you take it. If you take a shortcut, say what it costs.
- Do not report work as done that you have not verified. "I ran it and it failed" is a good
  answer. "Should be working now" is not.
