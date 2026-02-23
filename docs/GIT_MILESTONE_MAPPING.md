# Source-to-Migration Milestone Mapping

## Source Timeline (Captured)

| Source Commit | Date | Summary |
|---|---|---|
| 416bb28 | 2025-11-01 | initialize next.js app |
| a1ef000 | 2025-12-08 | add types and lib utilities |
| 9254e17 | 2025-12-15 | add API route handlers |
| 167c738 | 2025-12-15 | add SWR hooks |
| c129bb0 | 2026-02-21 | add layout/map/sidebar components |
| 1da82f5 | 2026-02-21 | add map/schedule/about pages |
| a7469ea | 2026-02-21 | polish build and config |
| ... | 2026-02-22 to 2026-03-07 | feature and bug-fix iterations |

## Migration Commit Strategy

1. Create migration commits by milestone order mirroring source progression.
2. For each migration commit, set both author and committer date to mapped source milestone date where feasible.
3. If exact one-to-one mapping is impossible, record nearest timestamp and reason.
4. Keep all history shaping on migration branch until explicitly approved to merge/push.

## Template For Timestamped Commit

```bash
git add <files>
GIT_AUTHOR_DATE="2025-12-08T14:30:00-0600" \\
GIT_COMMITTER_DATE="2025-12-08T14:30:00-0600" \\
  git commit -m "feat: port transit domain models"
```

## Required Safety Before Push

- `git diff --cached --name-only`
- `git diff --cached`
- verify no secrets/generated artifacts
- never force-push or rewrite shared remote history without explicit approval
