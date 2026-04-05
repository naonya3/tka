#!/bin/bash
WORKTREE="/tmp/$TKA_TICKET_ID"
git worktree add "$WORKTREE" -b "$TKA_TICKET_ID" 2>/dev/null || true
tka --base "$TKA_BASE_PATH" update "$TKA_TICKET_ID" --set "worktree=$WORKTREE"
