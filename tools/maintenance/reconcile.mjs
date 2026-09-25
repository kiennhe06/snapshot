// Snapshot data-integrity maintenance.
//
// Recomputes every denormalized counter from its source-of-truth documents,
// backfills derived fields, and purges expired ephemeral docs. Safe to run
// repeatedly — it only writes when a value is actually wrong.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccount.json node reconcile.mjs        # dry run (report only)
//   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccount.json node reconcile.mjs --fix  # apply fixes
//
// Get a service account key from Firebase console →
//   Project settings → Service accounts → Generate new private key
// and point GOOGLE_APPLICATION_CREDENTIALS at it (never commit that file).

import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const APPLY = process.argv.includes('--fix');

// Prefer an explicit key path; fall back to application-default credentials.
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
initializeApp({
  credential: keyPath
    ? cert(JSON.parse(readFileSync(keyPath, 'utf8')))
    : applicationDefault(),
});
const db = getFirestore();

let checked = 0;
let wrong = 0;

/** Applies `updates` to `ref` only if some field actually differs from `current`. */
async function reconcile(ref, current, updates, label) {
  checked++;
  const diff = {};
  for (const [k, v] of Object.entries(updates)) {
    if ((current[k] ?? 0) !== v) diff[k] = v;
  }
  if (Object.keys(diff).length === 0) return;
  wrong++;
  const shown = Object.entries(diff)
    .map(([k, v]) => `${k}: ${current[k] ?? 0} → ${v}`)
    .join(', ');
  console.log(`${APPLY ? 'FIX ' : 'DRIFT'}  ${label}  (${shown})`);
  if (APPLY) await ref.update(diff);
}

async function countCollection(ref) {
  const snap = await ref.count().get();
  return snap.data().count;
}

async function run() {
  console.log(`Snapshot maintenance — ${APPLY ? 'APPLY (writing fixes)' : 'DRY RUN (no writes)'}\n`);

  // 1. Posts: likesCount / commentsCount from subcollections; contributorIds backfill.
  const posts = await db.collection('posts').get();
  for (const post of posts.docs) {
    const data = post.data();
    const likes = await countCollection(post.ref.collection('likes'));
    const comments = await countCollection(post.ref.collection('comments'));

    const updates = { likesCount: likes, commentsCount: comments };
    // A post must list its author as a contributor, or profile grids miss it.
    const contrib = data.contributorIds ?? [];
    if (data.authorId && !contrib.includes(data.authorId)) {
      updates.contributorIds = [data.authorId];
    }
    await reconcile(post.ref, data, updates, `post ${post.id}`);

    // 1b. replyCount on each root comment.
    const commentDocs = await post.ref.collection('comments').get();
    const replyCounts = {};
    for (const c of commentDocs.docs) {
      const parent = c.data().parentId;
      if (parent) replyCounts[parent] = (replyCounts[parent] ?? 0) + 1;
    }
    for (const c of commentDocs.docs) {
      if (c.data().parentId) continue; // only roots carry replyCount
      await reconcile(
        c.ref,
        c.data(),
        { replyCount: replyCounts[c.id] ?? 0 },
        `comment ${c.id.slice(0, 8)} (post ${post.id})`,
      );
    }
  }

  // 2. Users: follower/following/post counters, plus expired-note cleanup.
  const now = Timestamp.now();
  let purged = 0;
  const users = await db.collection('users').get();
  for (const user of users.docs) {
    const uid = user.id;
    const followers = await countCollection(user.ref.collection('followers'));
    const following = await countCollection(user.ref.collection('following'));

    // postsCount = non-archived posts the user contributes to.
    const authored = await db
      .collection('posts')
      .where('contributorIds', 'array-contains', uid)
      .get();
    const postsCount = authored.docs.filter(
      (p) => p.data().isArchived !== true,
    ).length;

    await reconcile(
      user.ref,
      user.data(),
      { followersCount: followers, followingCount: following, postsCount },
      `user ${user.data().username || uid}`,
    );

    // Inbox note (users/{uid}/meta/note) expires after 24h.
    const noteRef = user.ref.collection('meta').doc('note');
    const note = await noteRef.get();
    const expiresAt = note.data()?.expiresAt;
    if (note.exists && expiresAt && expiresAt.toMillis() < now.toMillis()) {
      console.log(`${APPLY ? 'PURGE' : 'STALE'}  note of ${uid} (expired)`);
      if (APPLY) await noteRef.delete();
      purged++;
    }
  }

  // 3. Purge expired stories.
  const stories = await db
    .collection('stories')
    .where('expiresAt', '<', now)
    .get();
  for (const s of stories.docs) {
    console.log(`${APPLY ? 'PURGE' : 'STALE'}  story ${s.id} (expired)`);
    if (APPLY) await s.ref.delete();
    purged++;
  }

  console.log(
    `\nDone. Checked ${checked} docs, ${wrong} had drifted, ${purged} expired docs ${APPLY ? 'purged' : 'stale'}.`,
  );
  if (!APPLY && (wrong > 0 || purged > 0)) {
    console.log('Re-run with --fix to apply.');
  }
  process.exit(0);
}

run().catch((e) => {
  console.error('Maintenance failed:', e);
  process.exit(1);
});
