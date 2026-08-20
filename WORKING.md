# WORKING.md — concurrent agent coordination

Two agents work in this repo at the same time. This file is the lock table. Claim files here
**before** editing them; delete your claim when you are done and the file is open again.

Advisory, not enforced. It works only if both sides read it before touching anything.

---

## Rules

1. **Claim before you edit.** Add your files to your section below, then edit. If a file is in
   the other agent's section, do not touch it — say what you need and wait.
2. **Release when done.** Delete the entry as soon as the work is committed. A stale claim is
   worse than no claim; it blocks the other agent for no reason.
3. **Never revert, stash, or checkout a file you did not claim.** `git checkout -- <file>`,
   `git stash`, and `git clean` destroy the other agent's uncommitted work with no recovery.
   This applies even when the file is broken and you are "just fixing it".
4. **Only edit your own section of this file.** It is itself a shared file. Append to yours,
   never rewrite the whole document.
5. **Commit early on your own branch.** Commits are the real safety net; this file is only a
   convention. Uncommitted work is unrecoverable if the other agent makes a mistake.
6. **Do not leave `main` or a shared branch non-compiling across a handoff.** If you must stop
   mid-refactor, either finish the call sites or note it explicitly under **Known broken** below,
   so the other agent doesn't waste a cycle diagnosing your work in progress.
7. **Shared files are claimed briefly and released immediately.** Both agents will inevitably
   need `pubspec.yaml`, `app_constants.dart`, `app_router.dart`, `providers.dart`, and
   `.gitignore`. Claim, make the one edit, commit, release. Do not hold these for hours.
8. **Announce cross-cutting refactors before starting.** Removing a model, renaming a provider,
   or changing a widget's constructor breaks files you have not claimed. Those need agreement
   first, not a claim.

### Hot spots — highest collision risk

`map_page.dart` (845 lines) and `map_page_stop_sheet.dart` (1,395) are one Dart library joined by
`part` directives. Editing either can break the other. Treat them as a single unit: claim both or
neither.

---

## Known broken right now

- `lib/src/features/map/presentation/map_page.dart:788` passes `onGetEta:` to
  `_StopDetailSheet`, which no longer accepts it. `eta_result_model.dart` is deleted and the ETA
  params are stripped from the sheet, but this call site was not updated.
  **Owner: Agent B (ETA removal).** `flutter analyze` → 7 errors until it lands.

---

## Agent A — Flutter app: audit, guidelines, announcements feature

**Scope:** service alerts / announcements feature, `CLAUDE.md` and `docs/`, Play Store
readiness items, app-side bug fixes. Not the web port, not the Next.js retirement.

### Currently editing

| File | Why | Status |
|---|---|---|
| `lib/src/data/models/announcement.dart` | new — alert model | uncommitted, new file |
| `lib/src/data/repositories/announcements_repository_impl.dart` | new — cache-first fetch | uncommitted, new file |
| `lib/src/domain/repositories/announcements_repository.dart` | new — interface | uncommitted, new file |
| `lib/src/features/announcements/**` | new — controller, inbox, banner | uncommitted, new files |
| `assets/data/announcements.json` | new — bundled offline fallback | uncommitted, new file |
| `lib/src/core/constants/app_constants.dart` | **shared** — added poll intervals + endpoint getter | uncommitted, releasing on next commit |
| `lib/src/app/router/app_router.dart` | **shared** — added `/announcements` route | uncommitted, releasing on next commit |
| `lib/src/features/settings/presentation/settings_page.dart` | replaced the dead "Alerts" tile, added unread badge | uncommitted, releasing on next commit |
| `pubspec.yaml` | **shared** — registered the new asset | uncommitted, releasing on next commit |

### Need, but not claiming yet

- `lib/src/features/map/presentation/map_page.dart` — one insertion to show the severe-alert
  banner above the map. **Blocked on Agent B finishing the ETA removal**, since that file is
  currently broken and part of the map/stop-sheet unit. Will claim both map files, make the one
  edit, and release same-day. Flagging now rather than surprising you.

### Done and committed (branch `fix/working-tree-regressions`)

- `CLAUDE.md` (moved to repo root), `docs/AUDIT_2026-08-19.md`, `docs/REMEDIATION_PLAN.md`,
  `docs/ANNOUNCEMENTS_DESIGN.md`
- `.gitignore` — stopped ignoring `docs/` and `analysis_options.yaml`
- `lib/src/core/network/dio_provider.dart` — restored the `kIsWeb` User-Agent guard
- `pubspec.yaml` / `pubspec.lock` — committed the `flutter_native_splash` removal
- `lib/src/core/theme/app_theme.dart`, `schedule_page.dart` — committed as found

**Read `CLAUDE.md` before editing anything.** It carries the architecture invariants, the secret
and cost rules, the commit format, and the measured analyze/test baseline.

---

## Agent B — (web port / Next.js retirement / ETA removal)

_Agent B: add your scope and claims here. Do not edit Agent A's section._

### Currently editing

| File | Why | Status |
|---|---|---|
| _(unclaimed)_ | | |

---

## Log

Append a line when you release a claim, so the other agent can see the file is free without
diffing this document.

- 2026-08-19 — Agent A: claimed the announcements feature files listed above.
- 2026-08-19 — Agent A: reverted an in-progress edit of `map_page.dart` back to HEAD after a
  failed refactor. Verified beforehand that the file was unmodified, so no other work was lost —
  but this is exactly the case rule 3 exists to prevent. Will not touch it again unclaimed.
