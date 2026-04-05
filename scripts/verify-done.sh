#!/bin/bash
WORKTREE=$(tka --base "$TKA_BASE_PATH" show "$TKA_TICKET_ID" | jq -r '.fields.worktree')
cd "$WORKTREE" || { echo "Worktree not found: $WORKTREE" >&2; exit 1; }

# 1. uncommitted changes がないこと
git diff --quiet && git diff --cached --quiet || {
  echo "Uncommitted changes exist. Commit your work first." >&2; exit 1
}

# 2. テスト
dart test || { echo "Tests failed." >&2; exit 1; }

# 3. 静的解析
dart analyze --fatal-infos || { echo "Analyze failed." >&2; exit 1; }

# 4. AI レビュー（独立コンテキスト）
RESULT=$(claude --dangerously-skip-permissions -p \
  "You are reviewing a code change for tka (a CLI tool).
Run these commands:
1. tka --base $TKA_BASE_PATH show $TKA_TICKET_ID (read the ticket)
2. cd $WORKTREE && git diff main

Check ALL of the following:
- Are help texts updated if the change affects CLI behavior?
- Is README updated if the change adds/modifies user-facing features?
- Does the code change match what the ticket describes?

Respond with exactly 'PASS' if everything looks good.
Respond with 'FAIL:' followed by specific issues if not." \
  2>/dev/null)

if echo "$RESULT" | grep -q "^PASS"; then
  exit 0
fi

echo "$RESULT" >&2
exit 1
