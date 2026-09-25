#!/usr/bin/env bash
#
# Enables Firestore native TTL so expired stories and inbox notes are deleted
# automatically by Firestore — no Cloud Functions, no billing beyond normal
# Firestore usage. Run once per project (idempotent).
#
# Prerequisites: gcloud CLI authenticated with access to the project.
#   gcloud auth login
#
# Native TTL deletes a document some time after the timestamp in its TTL field
# passes (usually within 24-72h). The app already hides expired docs by querying
# `expiresAt > now`, so TTL is purely storage cleanup.

set -euo pipefail

PROJECT="${1:-vibely-90fda}"

echo "Enabling Firestore TTL on project: $PROJECT"

# Stories expire 24h after creation (stories/{id}.expiresAt).
gcloud firestore fields ttl update expiresAt \
  --collection-group=stories \
  --project="$PROJECT" \
  --async

# Inbox notes expire 24h after posting (users/{uid}/meta/note.expiresAt).
# The `meta` subcollection currently only holds the note document.
gcloud firestore fields ttl update expiresAt \
  --collection-group=meta \
  --project="$PROJECT" \
  --async

echo "TTL policies requested. Check status with:"
echo "  gcloud firestore fields list --collection-group=stories --project=$PROJECT"
