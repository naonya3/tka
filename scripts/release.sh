#!/bin/bash
TICKET_JSON=$(tka --base "$TKA_BASE_PATH" show "$TKA_TICKET_ID")
WORKTREE=$(echo "$TICKET_JSON" | jq -r '.fields.worktree')
TITLE=$(echo "$TICKET_JSON" | jq -r '.title')

# Repo root is parent of .tka directory
REPO_ROOT=$(dirname "$TKA_BASE_PATH")

# merge from repo root (main is checked out there)
cd "$REPO_ROOT" || { echo "Repo root not found: $REPO_ROOT" >&2; exit 1; }
git merge "$TKA_TICKET_ID" || { echo "Merge failed" >&2; exit 1; }

# AI-driven version bump
CURRENT=$(grep '^version:' pubspec.yaml | awk '{print $2}')
DIFF=$(git diff HEAD~1 -- ':(exclude)pubspec.yaml')

NEW_VERSION=$(claude --dangerously-skip-permissions -p \
  "You are deciding the version bump for tka (a CLI tool).

Current version: $CURRENT
Ticket: $TKA_TICKET_ID — $TITLE

Here is the diff being released:
$DIFF

Rules (semver):
- While version is 0.x:
  * minor (0.X.0): new features or breaking changes
  * patch (0.0.X): bug fixes, docs, refactors, internal improvements
- After 1.0:
  * major (X.0.0): breaking changes
  * minor (0.X.0): new features
  * patch (0.0.X): bug fixes
- If the change is docs-only, test-only, or has no user-facing impact: respond with NONE

Respond with ONLY the new version number (e.g. 0.3.0) or NONE.
No explanation, no extra text." \
  2>/dev/null | tr -d '[:space:]')

if [ "$NEW_VERSION" = "NONE" ] || [ -z "$NEW_VERSION" ]; then
  echo "No version bump needed. Releasing as $CURRENT."
  NEW_VERSION="$CURRENT"
else
  echo "Version bump: $CURRENT -> $NEW_VERSION"
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
  git add pubspec.yaml
  git commit -m "Bump version to $NEW_VERSION for $TKA_TICKET_ID"
fi

# tag & push (skip if tag already exists)
git tag "v$NEW_VERSION" 2>/dev/null || { echo "Tag v$NEW_VERSION already exists, skipping." >&2; }
git push || { echo "Push failed" >&2; exit 1; }
git push origin "v$NEW_VERSION" || { echo "Tag push failed" >&2; exit 1; }

# cleanup worktree
git worktree remove "$WORKTREE" 2>/dev/null || true
git branch -d "$TKA_TICKET_ID" 2>/dev/null || true
