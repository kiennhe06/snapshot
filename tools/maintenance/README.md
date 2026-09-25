# Snapshot maintenance

Data-integrity tooling for the Firestore backend. The app keeps denormalized
counters in sync client-side (via transactions), but seed scripts, aborted
writes, and manual edits can still cause drift. This tool is the safety net that
recomputes everything from the source-of-truth documents.

## What `reconcile.mjs` does

| Target | Recomputed from |
| --- | --- |
| `posts/{id}.likesCount` | count of `posts/{id}/likes/*` |
| `posts/{id}.commentsCount` | count of `posts/{id}/comments/*` |
| `posts/{id}.contributorIds` | backfilled to `[authorId]` if missing |
| `comments/{id}.replyCount` | count of child comments |
| `users/{id}.followersCount` | count of `users/{id}/followers/*` |
| `users/{id}.followingCount` | count of `users/{id}/following/*` |
| `users/{id}.postsCount` | non-archived posts the user contributes to |
| expired `stories/*` and `users/*/meta/note` | deleted |

It only writes fields that are actually wrong, and prints every drift it finds.

## Setup (once)

1. Firebase console → **Project settings → Service accounts → Generate new
   private key**. Save it as `tools/maintenance/serviceAccount.json`
   (git-ignored — never commit it).
2. Install deps:
   ```bash
   cd tools/maintenance && npm install
   ```

## Run

```bash
cd tools/maintenance
export GOOGLE_APPLICATION_CREDENTIALS=./serviceAccount.json

npm run reconcile        # dry run — reports drift, writes nothing
npm run reconcile:fix    # applies the fixes
```

Always dry-run first and read the report.

## Automation

- **Scheduled:** `.github/workflows/reconcile.yml` runs the dry-run weekly and on
  demand. Add the service-account JSON as the `FIREBASE_SERVICE_ACCOUNT` repo
  secret to enable it.
- **Native TTL:** `scripts/enable-firestore-ttl.sh` turns on Firestore TTL so
  expired stories/notes are purged automatically — run it once and the tool's
  purge step becomes a backstop rather than the primary cleanup.
