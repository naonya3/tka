#!/bin/bash
TICKET_JSON=$(tka --base "$TKA_BASE_PATH" show "$TKA_TICKET_ID")
WORKTREE=$(echo "$TICKET_JSON" | jq -r '.fields.worktree')
TITLE=$(echo "$TICKET_JSON" | jq -r '.fields.title')

# Repo root is parent of .tka directory
REPO_ROOT=$(dirname "$TKA_BASE_PATH")

VERSION=$(cd "$WORKTREE" && grep '^version:' pubspec.yaml | awk '{print $2}')

# merge & push from repo root (main is checked out there)
cd "$REPO_ROOT" || { echo "Repo root not found: $REPO_ROOT" >&2; exit 1; }
git merge "$TKA_TICKET_ID" || { echo "Merge failed" >&2; exit 1; }
git tag "v$VERSION" || { echo "Tag creation failed" >&2; exit 1; }
git push || { echo "Push failed" >&2; exit 1; }
git push origin "v$VERSION" || { echo "Tag push failed" >&2; exit 1; }

# cleanup worktree
git worktree remove "$WORKTREE" 2>/dev/null || true
git branch -d "$TKA_TICKET_ID" 2>/dev/null || true
