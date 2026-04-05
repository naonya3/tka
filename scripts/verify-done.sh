#!/bin/bash
WORKTREE=$(tka --base "$TKA_BASE_PATH" show "$TKA_TICKET_ID" | jq -r '.fields.worktree')
cd "$WORKTREE" || { echo "Worktree not found: $WORKTREE" >&2; exit 1; }

# 1. uncommitted changes がないこと
git diff --quiet && git diff --cached --quiet || {
  echo "Uncommitted changes exist. Commit your work first." >&2; exit 1
}

# 2. pubspec.yaml のバージョンが main と異なること
CURRENT=$(grep '^version:' pubspec.yaml | awk '{print $2}')
MAIN=$(git show main:pubspec.yaml | grep '^version:' | awk '{print $2}')
[ "$CURRENT" != "$MAIN" ] || {
  echo "pubspec.yaml version not bumped (still $CURRENT). Update the version." >&2; exit 1
}

# 3. バージョンが semver 形式であること
echo "$CURRENT" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo "Invalid version format: $CURRENT. Expected semver (e.g. 1.2.3)." >&2; exit 1
}

# 4. テスト
dart test || { echo "Tests failed." >&2; exit 1; }

# 5. 静的解析
dart analyze --fatal-infos || { echo "Analyze failed." >&2; exit 1; }

# 6. AI レビュー（独立コンテキスト）
RESULT=$(claude --dangerously-skip-permissions -p \
  "You are reviewing a code change for tka (a CLI tool).
Run these commands:
1. tka --base $TKA_BASE_PATH show $TKA_TICKET_ID (read the ticket)
2. cd $WORKTREE && git diff main
3. grep '^version:' $WORKTREE/pubspec.yaml (current version)
4. git show main:pubspec.yaml | grep '^version:' (previous version)

Check ALL of the following:
- Are help texts updated if the change affects CLI behavior?
- Is README updated if the change adds/modifies user-facing features?
- Does the code change match what the ticket describes?
- Is the version bump appropriate? Rules:
  * While 0.x: minor (0.x.0) for new features or breaking changes, patch (0.0.x) for bug fixes/docs/refactors
  * After 1.0: major for breaking changes, minor for new features, patch for bug fixes

Respond with exactly 'PASS' if everything looks good.
Respond with 'FAIL:' followed by specific issues if not." \
  2>/dev/null)

if echo "$RESULT" | grep -q "^PASS"; then
  exit 0
fi

echo "$RESULT" >&2
exit 1
