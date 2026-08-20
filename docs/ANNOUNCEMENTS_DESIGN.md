# Announcements & Push — Design Proposal

Service alerts, detours, "no service today", weather delays, and product notes — deliverable to
users without shipping an app release.

**Status: proposal. Not built. Needs approval, and needs a dependency decision (§7).**

---

## 1. The core decision: separate delivery from content

The instinct is to put the message in the push payload. Don't. Push is a **notification**, not a
**source of truth**.

```
            ┌──────────────────────────────┐
            │  announcements.json          │  ← the source of truth
            │  served from /api/announcements
            └──────────────┬───────────────┘
                           │ cache-first fetch
   ┌───────────────────────┼───────────────────────┐
   │                       │                       │
┌──▼──────┐         ┌──────▼──────┐         ┌──────▼──────┐
│ Android │         │    Web      │         │  iOS (later)│
└──▲──────┘         └─────────────┘         └──────▲──────┘
   │                                               │
   └──────── FCM push: "something changed" ────────┘
                (carries an id, not the content)
```

Why this shape:

| Reason | Consequence if you inline content in the push instead |
|---|---|
| Users who deny notifications still see alerts | ~30-50% of your users see nothing, ever |
| Web has no reliable push story on iOS Safari | Web users miss alerts |
| Push is best-effort — FCM drops messages | Silent delivery failures with no recovery |
| One payload for all clients | Three divergent formats to maintain |
| Alerts can be *edited* and *expired* after sending | A sent push is immutable; a stale "no service today" stays on screen |
| Renders offline from cache | Nothing to show without connectivity |

The push tells the app *to look*. The document tells the app *what to say*. If push never
arrives, a foreground poll still finds it.

---

## 2. Where the content lives — recommendation

**Recommendation: a JSON document served by the same thin API tier that Phase 1 already keeps
alive.** Not Firestore.

| | Vercel JSON endpoint (recommended) | Firestore |
|---|---|---|
| New Flutter dependencies | **0** | `cloud_firestore` (heavy, +native SDKs) |
| Where you edit | A JSON file in git, or a tiny authed admin route | Firebase console |
| Change is reviewable / revertable | **Yes — it's a commit** | No; console edits leave no diff |
| Auth to publish | Existing git access, or one shared secret | Firebase IAM |
| Cost at your scale | Free (already deployed) | Free tier, but reads scale with users |
| Realtime | No — poll + push | Yes |
| Offline cache | We build it (~40 lines, and Phase 1 needs the same pattern anyway) | Built into the SDK |
| Web bundle size | Unaffected | Significantly larger |

Firestore's real advantages — realtime and a built-in offline cache — are worth little here.
Announcements change a few times a week, not a few times a second, and the cache-first repository
pattern is being built in Phase 1 regardless.

The deciding factor is **operational**: editing a JSON file in git means every alert you publish
is diffed, reviewed, timestamped, and revertable. A console edit at 6 AM during a snow closure is
not. For text that goes to every rider's phone, that audit trail is worth more than realtime.

**You still need a Firebase project** — FCM requires one. This recommendation is about where the
*content* lives, not whether you touch Firebase at all.

### Publishing workflow

1. Edit `announcements.json` in the API repo.
2. Commit and push → Vercel redeploys in seconds.
3. A `POST /api/announcements/notify` (shared-secret authed) fans out the FCM topic message.

Step 3 is deliberately separate from step 2, so you can stage an alert without notifying, or
re-notify without editing.

**Serve `announcements.json` as a static CDN asset, not a function.** With
`Cache-Control: public, s-maxage=60, stale-while-revalidate=600` and a strong `ETag`, it is
edge-cached, 304s are nearly free, and origin sees roughly one request per POP per minute
regardless of user count — so "someone hammers it" costs bandwidth, not per-invocation compute.
Do **not** inherit `SECURITY_HEADERS` from the existing `lib/rateLimit.ts`, which sets
`Cache-Control: private, no-store` and would make a static document uncacheable.

Rate-limit the authed `POST /api/announcements/notify` instead — that one is genuinely dangerous.
Anyone who obtains the shared secret can fan out arbitrary pushes to every installed device. It
needs a real limiter, an idempotency key, an audit log, and a documented secret-rotation plan.

---

## 3. Payload schema

Versioned from day one. Additive changes bump `minor`; breaking changes bump `schema`.

```jsonc
{
  "schema": 1,
  "generated_at": "2026-08-19T14:03:00Z",
  "announcements": [
    {
      "id": "2026-08-19-hardy-detour",     // stable, unique, never reused
      "kind": "service_alert",             // service_alert | product_update
      "priority": "critical",              // critical | normal | low
      "title": "Hardy St detour in effect",
      "body": "Blue route is detouring via 4th St until further notice. Stops 12-16 are not being served.",
      "scope": { "routes": ["blue"] },     // omit `routes` for agency-wide
      "starts_at": "2026-08-19T05:00:00Z",
      "ends_at":   "2026-08-26T23:59:00Z", // null = until removed
      "url": null,                          // optional "learn more"
      "updated_at": "2026-08-19T14:03:00Z"
    }
  ]
}
```

Field notes:

- **`id`** is the identity for push correlation. Never reuse one; editing an existing alert keeps
  the `id` and bumps `updated_at`.
- **Read and dismissed state must key on `(id, updated_at)`, not `id` alone.** Otherwise: publish
  "Hardy St detour, minor delays" → rider dismisses → you escalate the *same id* to "Blue route
  not running today" → **that rider never sees it.** Bumping `updated_at` resurfaces the alert.
  This is a rider-stranded-at-a-stop failure and it is the highest-severity trap in this design.
- **`priority: critical`** pins a banner to the top of the Map screen. This is the "no service
  today" case. Use it sparingly — everything critical means nothing is.
- **`scope.routes`** maps to FCM topics *and* to in-app filtering. A rider who only uses Gold
  should not get Blue detour banners.
- **`starts_at` / `ends_at`** give you scheduling and expiry for free. The client filters on
  them, so an expired alert disappears **without** you having to edit anything — which matters
  when the closure ends at 5 AM Sunday.
- **All timestamps are UTC ISO-8601.** The app converts for display. Given that the schedule
  engine currently has no timezone concept at all (`AUDIT` S4-4), this payload should not repeat
  that mistake.
- `kind` maps 1:1 to a notification channel (§5).

**Client must ignore unknown fields and unknown enum values** so the server can add both without
breaking shipped apps. An unrecognised `priority` degrades to `normal`; an unrecognised `kind` is
dropped.

### Align the schema with GTFS-Realtime Service Alerts

Hub City Transit is a City of Hattiesburg service, and will sooner or later be asked for GTFS
static + GTFS-RT feeds (Google Maps, Apple Maps, Transit app, NTD reporting). A bespoke schema
that diverges from the standard is the one genuinely bad option — it means a translation layer
*and* a shipped-client migration the day a real alerts feed appears.

Do **not** ship raw GTFS-RT to the client; it is protobuf-first and its JSON mapping is a
convention rather than a spec. Instead define this payload as a **lossless projection of
GTFS-RT `Alert`**, adopting now, at zero cost:

| Adopt | Replaces / adds |
|---|---|
| `cause` + `effect` | Splits "what happened" from urgency. Detour vs no-service vs reduced-service vs stop-moved drive different UI and different rider decisions. |
| `severity_level` (INFO / WARNING / SEVERE) | Standard enum instead of bespoke `priority` |
| **repeated** `active_period` | Fixes a real gap: "weekdays 6–9am for two weeks" is unrepresentable with a single `starts_at`/`ends_at` |
| `informed_entity[]` — `{route_id, stop_id?, direction_id?}` | Answers open question §2 (per-stop scope) today |
| `TranslatedString` for `header_text` / `description_text` | Answers open question §5 (Spanish) today, and retrofitting it later is a breaking change |

Keep `kind` as a local extension — GTFS-RT has no concept of `product_update`, which is half the
stated use case. Also add a document-level `max_age` (so the client has a rule for when the cache
is too stale to trust) and a `body` length cap (the cache goes into `SharedPreferences`, which on
Android is an XML file read fully into memory).

---

## 4. In-app surfaces

Three, in increasing intrusiveness:

| Surface | Trigger | Behaviour |
|---|---|---|
| **Map banner** | `priority: critical` and in-window and route-relevant | Pinned above the map, dismissible per-`(id, updated_at)`. Dismissing hides it until the alert is edited. |
| **Inbox** | All in-window announcements | Reachable from Settings and from the banner. Read/unread state, newest first, grouped by `kind`. |
| **Unread badge** | Any unread in-window announcement | On the Settings tab icon |

All three read from the same cached document. **All three work with notifications denied and with
no network** — that is the point of the design.

### Caching

Standard cache-first, matching the pattern Phase 1 establishes:

1. Render from `SharedPreferences`-cached JSON immediately (no spinner on a warm start).
2. Fetch in the background with an `If-None-Match` / ETag.
3. On 200, validate **per record** — `try`/`catch` around each element, drop the bad one, keep
   the rest, count the drops. Reject the whole document only if `schema` is unrecognised or
   `announcements` is not a list. Do **not** copy `_loadStops`, where one bad field currently
   throws out all seven routes (`AUDIT` S4-1). On 304, keep the cache. On error, keep the cache —
   except for `critical`, see below.
4. Ship a bundled `assets/data/announcements.json` containing `{"schema":1,"announcements":[]}`
   as the cold-start-offline fallback.
5. **"Keep the cache silently" is wrong for `critical`.** If the endpoint has been failing for
   hours, continuing to pin a critical banner asserts current fact from stale data. Past a
   threshold, degrade it to a "may be out of date" presentation rather than dropping or trusting
   it.

Refresh on app foreground, on push receipt, **and on a foreground-gated conditional poll**:
60s while a `critical` alert is active or the Inbox is open, 5 min otherwise, fully paused on
`AppLifecycleState.paused`, always with `If-None-Match`.

An earlier draft refused any timer, reasoning that the app already has one runaway poll loop
(`AUDIT` S2-1). That was a category error. S2-1 is a 3-second poll with no `autoDispose` and no
lifecycle gating, at 1,200–2,400 req/hr/user against a public ArcGIS FeatureServer. A 5-minute
conditional GET against a CDN-cached static document is ~12 req/hr, returns 304 with an empty
body, and is three orders of magnitude cheaper. Without it, a rider who foregrounds the app at
7:00 and watches the map until 7:40 never sees an alert published at 7:20 — during steps 1–5
there is no push to save them, so worst-case latency is *unbounded*.

Note this requires an `AppLifecycleListener`, which **does not exist anywhere in `lib/` today**
(zero hits for `WidgetsBindingObserver`/`didChangeAppLifecycleState`). It is the same mechanism
Phase 4 task 4-1 needs, so build it once and share it. `StatefulShellRoute` + `IndexedStack` +
`wantKeepAlive` means tab switches are *not* lifecycle events either.

**Staleness must be visible.** If the cached document's `generated_at` is older than the poll
interval by a wide margin, the banner and inbox must say so ("last checked 41 minutes ago").
An alert system that cannot tell the user how fresh it is, isn't one.

### Read state

A `Set<String>` of seen `(id, updated_at)` pairs in `SharedPreferences`, pruned when an `id`
leaves the document. Local-only — no account system, so no cross-device sync.

`AndroidManifest.xml:10-12` sets `allowBackup="false"` and `fullBackupContent="false"`, and
`data_extraction_rules.xml` excludes everything from both cloud backup and device transfer. So on
reinstall or a new device **all read/dismissed state is lost**: every past alert re-marks unread
and every dismissed banner reappears. On a long-running detour that means a full-width banner the
user already dismissed, back again. Deliberate for a location app — but know that opting read
state into backup later is a two-file change, not a one-flag change.

---

## 5. Push (FCM)

### Channels

Android notification channels are **immutable once created** — importance cannot be changed
afterward without a new channel ID. Get these right the first time:

| Channel ID | Name | Importance | Default |
|---|---|---|---|
| `service_alerts_v1` | Service Alerts | `HIGH` | on |
| `product_updates_v1` | App Updates | `LOW` | on |

The `_v1` suffix is deliberate — it is the only escape hatch if importance turns out wrong.
Two caveats the version scheme does not remove: the *user* can change importance at any time and
once they do the app is locked out permanently; and migrating to `_v2` **resets every user's
opt-out to the new default**, so a rider who deliberately silenced product updates starts getting
them again. Migration also requires calling `deleteNotificationChannel('..._v1')`, or the user
sees two Service Alerts channels in system settings forever, one of them dead.

Both must be independently opt-out-able in Settings. Play policy requires it, and a rider who
wants detour alerts but not feature announcements is the common case.

The **system** channel toggle already satisfies policy. If you also add an app-level toggle, it
must read `NotificationManagerCompat.areNotificationsEnabled()` plus channel importance and
reflect reality — otherwise the app says "on" while the OS has the channel blocked, which is two
sources of truth that will disagree. Note `settings_page.dart:142` currently ships exactly the
failure this design condemns: an "Alerts & Notifications" tile that opens location settings and
persists nothing.

### Topics

| Topic | Who |
|---|---|
| `all_v1` | Everyone |
| `route_blue_v1` … `route_purple_v1` | Per-route subscribers (7 topics) |

Subscription follows the user's route interest. Topic names are versioned for the same reason as
channels.

### Permission flow

Android 13+ requires runtime `POST_NOTIFICATIONS`. **Do not request it at launch.**

The correct sequence — and note the app currently gets the *location* equivalent of this wrong
(`AUDIT` S1-7), so this is a chance to set the pattern properly:

1. User reaches a moment where notifications are obviously useful (the inbox, or a Settings
   toggle they just enabled).
2. Show in-app rationale explaining what they'll receive and how often.
3. **Only then** trigger the OS dialog.
4. Handle permanent denial with an `openAppSettings()` path and honest UI — never a button that
   silently does nothing.

Denied is a first-class state, not an error: the inbox and banner keep working.

### Foreground display

Android does not show a system notification while the app is foregrounded. Either surface it
in-app (a snackbar linking to the inbox) or post a local notification. This needs
`flutter_local_notifications` — see §7.

---

## 6. Where the code goes

Follows the existing layering (`CLAUDE.md` §3). No new patterns.

```
core/notifications/
  notification_service.dart          # interface — no Flutter, no Firebase
  fcm_notification_service.dart      # Android/iOS impl
  noop_notification_service.dart     # web fallback + tests
core/permissions/
  permission_service.dart            # interface; wraps POST_NOTIFICATIONS and location
data/models/announcement.dart        # freezed + json_serializable
data/repositories/announcements_repository_impl.dart
domain/repositories/announcements_repository.dart
features/announcements/
  presentation/announcements_inbox_page.dart
  presentation/announcement_banner.dart
  application/announcements_controller.dart
```

`NotificationService` is the platform seam. **iOS becomes an added implementation plus APNs
config, not a redesign** — which is the §5e requirement from the brief. The `noop` implementation
covers web and keeps tests free of Firebase.

**Design one constraint in from step 2, even though push is step 6.**
`FirebaseMessaging.onBackgroundMessage` runs in a *separate Dart isolate* with a fresh
`ProviderScope` and no `main()` — so `dotenv.load()` never runs and `baseApiUrl` is `''`
(`app_constants.dart:16`). Any "refresh on push receipt" logic written against a dotenv global
will silently no-op. The repository's base URL must therefore come from `--dart-define`
(remediation task 1-4) via explicit constructor injection, **not** from a loaded singleton. That
costs nothing now and removes the entire step-6 surprise.

Likewise, do remediation task 2-1 (pin `compileSdk`/`targetSdk`/`minSdk`) **before** step 1 —
Firebase's BoM forces a concrete `compileSdk` and a `minSdk` floor, so adding it later re-opens a
Play blocker you already closed.

Prerequisite: the **typed preferences layer** (`AUDIT` S4-8). The current one-`StateNotifier`-per-
toggle pattern would mean a new class and a new hardcoded string key per channel, and it has a
live lost-write race that would silently revert a user's opt-out.

---

## 7. Dependencies — needs your approval

Three new packages. Per `CLAUDE.md` §4, iOS and web support checked before proposing:

| Package | Why | iOS | Web | Note |
|---|---|---|---|---|
| `firebase_core` | Required by any Firebase package | yes | yes | Unavoidable if you want FCM |
| `firebase_messaging` | FCM | yes | yes | Web push works except iOS Safari, which is unreliable |
| `flutter_local_notifications` | Display notifications while foregrounded | yes | **no** | Web degrades to in-app only — acceptable |

These are the boring, first-party, well-supported choice. All three are widely used and actively
maintained, which is more than can be said for `flutter_compass` already in the tree.

**Cost to be honest about:** `firebase_core` + `firebase_messaging` pull in native Firebase SDKs
and meaningfully increase APK size and build time. There is no lighter way to get reliable Android
push — self-hosted alternatives (ntfy, web push via VAPID) trade that cost for worse delivery and
much more infrastructure. FCM is the right call, but it is not free.

**Offsetting:** Phase 7 deletes 5 unused packages (`connectivity_plus`, `google_fonts`, `intl`,
`logger`, `cupertino_icons`), so net dependency count is roughly flat.

---

## 8. Play Store consequences

Adding push changes your compliance surface. All of this must land with the feature, not after:

- **`POST_NOTIFICATIONS`** in the manifest, with the rationale flow above.
- **Data Safety must be updated. Topic-only messaging does NOT avoid this** — an earlier draft
  of this document claimed it did, and that was wrong. `firebase_messaging` generates a
  registration token on first start whether or not you read it; `subscribeToTopic` is itself a
  token-scoped call; and Firebase Installations issues an FID sent to Google with the device IP.
  Play Data Safety covers data collected by the app **including third-party SDKs**, not just by
  your backend. Adding FCM means declaring **Device or other IDs — collected, shared with Google,
  for app functionality**, and re-examining the IP-derived location questions.

  Topic-only is still the right call: you avoid running a token database and its retention and
  deletion obligations. It is a simplicity win, not a compliance dodge.

- **A Data Safety change after launch triggers re-review and can hold up a release.** That is an
  argument for deciding the push question *before* first submission rather than at step 6.
- **Privacy policy must be updated** to describe notification data. The policy is already a
  blocker (`AUDIT` S0-6); fix it once, correctly, covering both location and notifications.
- Google Play requires notifications to be opt-out-able and non-deceptive. Do not use service
  alerts to deliver marketing.

---

## 9. Build order

| Step | Deliverable | Ships value? |
|---|---|---|
| 1 | Payload schema + endpoint + bundled fallback | Nothing user-visible yet |
| 2 | Repository + cache-first fetch + model | — |
| 3 | Typed preferences layer (`AUDIT` S4-8) | Fixes an existing lost-write bug |
| 4 | Inbox + unread state | **Yes — publishable alerts, no push, no Firebase** |
| 5 | Critical banner on Map | **Yes — the "no service today" case** |
| 6 | FCM + channels + permission flow + Settings opt-outs | Yes |
| 7 | iOS: APNs cert, entitlements, `NotificationService` impl | When `ios/` exists |

**Steps 1–5 deliver the whole feature with zero new dependencies and no Firebase.** Push is an
enhancement layered on top, not a prerequisite. If you want the fastest path to "I can tell my
riders something today", stop after step 5 and evaluate whether push is worth the three packages.

That is the recommendation: **build 1–5 first, then decide on push with real usage in hand.**

---

## 10. Open questions

1. **Who publishes?** If it is only you, a git commit is fine. If a dispatcher needs to post at
   5 AM without touching git, that changes the answer toward a small authed admin form — worth
   knowing now, because it is much cheaper to design in than to retrofit.
2. **Do alerts need per-stop scope**, or is per-route enough? Per-stop is more precise but a
   larger payload and a more complex editor.
3. **Should `critical` alerts be dismissible?** Currently proposed as yes. Non-dismissible is
   more forceful and more annoying.
4. **Retention** — how long do read announcements stay in the inbox? Proposed: they disappear
   when `ends_at` passes, with no archive.
5. **Localisation** — Hattiesburg has a meaningful Spanish-speaking population. If translated
   alerts are ever wanted, `title`/`body` should become `{"en": "...", "es": "..."}` maps **now**;
   retrofitting is a breaking schema change.
