#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Block direct git push
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|)git\s+push'; then
  echo "Direct git push is not allowed. Use: tka transition <id> --to released" >&2
  exit 2
fi

# Block direct gh release
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|)gh\s+release'; then
  echo "Direct gh release is not allowed. Use: tka transition <id> --to released" >&2
  exit 2
fi

# Block direct git merge to main
if echo "$COMMAND" | grep -qE '(^|\s|&&|\|)git\s+merge.*main|git\s+checkout\s+main\s*&&\s*git\s+merge'; then
  echo "Direct merge to main is not allowed. Use: tka transition <id> --to released" >&2
  exit 2
fi

exit 0
