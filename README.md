# tka

Ticket for Agents — a schema-driven ticket management CLI.

AI agents need task management too. But they can't read Kanban boards or parse Markdown tables. tka gives them a structured, JSON-in/JSON-out interface to create, track, and transition tickets — so they stay on task without human babysitting.

Every output is machine-readable JSON on stdout. Errors go to stderr as JSON. No human-friendly formatting — agents parse it directly and move on.

But there's one exception: `tka watch` gives you a real-time terminal dashboard to see what your agents are up to. It's surprisingly fun to watch.

## Quick Start

```bash
# Install
make && make install

# Initialize
tka init

# Check the schema spec so you know what to build
tka project schema

# Create a project from JSON (AI-friendly)
tka project add my-tasks --schema '{"fields":{"title":{"type":"string","required":true},"detail":{"type":"string"}},"states":{"initial":"todo","transitions":{"todo":["in_progress"],"in_progress":["done","todo"]}}}'

# Or use a built-in template
tka project add my-tasks --template tdd
```

## Usage

```bash
# --- Project management ---
tka project list                          # ["my-tasks", "bugs"]
tka project show <name>                   # Full definition as JSON
tka project schema                        # Schema spec for --schema input
tka project add <name> --template <tpl>   # Create from template
tka project add <name> --schema '<json>'  # Create from JSON
tka project archive <name> [--force]      # Archive a project
tka project unarchive <name>              # Restore archived project
tka project list --archived               # List archived projects
tka project templates                     # Available templates

# --- Tickets ---
tka create <project> --set title="Fix bug" --set detail="..."
tka list -p <project>                     # [{"id", "status"}, ...]
tka list -p <project> --status todo       # Filter by status
tka list -p <project> --where priority=p0 # Filter by field value
tka list -p <project> --fields id,status,title  # Select output fields
tka list -p <project> --sort -created_at --limit 5
tka list -p <project> --archived          # List archived tickets
tka show <id>                             # Full ticket JSON + available_transitions [{to, description?}]
tka update <id> --set field=value
tka transition <id> --to <status>
tka append <id> --field history --value "Done"
tka archive <id>

# --- Dashboard ---
tka watch                                 # Real-time TUI dashboard
```

## `tka watch` — The Fun Part

While every other command spits out JSON for machines, `watch` is for humans. It opens a full-screen terminal dashboard that updates in real-time as tickets change.

- **TAB** / **Shift+TAB**: Switch between projects
- **1-9**: Toggle status filters
- **0**: Reset filters
- **q**: Quit

Run it in a side terminal while your AI agents work. Watch tickets flow through states in real time.

## Long Text Input

CLI arguments aren't great for long text. Use pipes or file references:

```bash
# Pipe (recommended) — use - to read from stdin
echo "multi-line
detailed
description" | tka create proj --set title="Task" --set detail=-

# File reference
tka update <id> --set detail=@docs/design.md
```

## Why Schema-Driven?

AI agents make mistakes — wrong field names, invalid values, impossible state transitions. tka catches all of these at the CLI boundary and returns actionable error messages:

```
"status" is not a field. Use --status <value> to filter by status.
Cannot transition from 'todo' to 'done'. Available: in_progress
priority: must be one of [p0, p1, p2]
Unknown field: priorty
```

The schema enforces your workflow so agents don't need to memorize rules — they just try, read the error, and self-correct.

**What the schema guarantees:**

- **Required fields** — missing fields are rejected at creation time
- **Type checking** — string, number, date (with calendar validation), list, enum
- **Enum constraints** — only defined values accepted, with allowed values listed in errors
- **State machine** — only valid transitions allowed, terminal states enforced
- **Unknown fields** — typos and hallucinated fields rejected immediately
- **List protection** — list fields are append-only, no accidental overwrites

This means you can design any workflow — TDD cycles, bug triage, content pipelines — and trust that agents will follow it.

## Verify — Enforce Before Transitioning

Transitions can require a command to pass before proceeding. If the command exits non-zero, the transition is blocked.

```yaml
# In project YAML
states:
  initial: todo
  transitions:
    todo: [red]
    red:
      targets: [green]
      verify:
        green: "dart test"         # must pass before red → green
    green:
      targets: [done, red]
      verify:
        done: "./scripts/review.sh"  # review before done, but red needs no check
```

When an agent runs `tka transition ticket-001 --to green`, tka executes `dart test` first. If tests fail, the transition is rejected:

```json
{"error": "Verify failed for transition red → green. Command: dart test (exit code 1). Output: Expected 3 tests, found 0"}
```

The agent reads the error and self-corrects — write the tests, run again.

### Using AI as a reviewer

Verify can run any command, including `claude -p` for AI-powered review:

```bash
#!/bin/bash
# scripts/review.sh
RESULT=$(claude --dangerously-skip-permissions -p \
  "Run 'tka --base $TKA_BASE_PATH show $TKA_TICKET_ID' to read the ticket.
   Review whether the implementation meets the requirements.
   Respond with exactly 'PASS' if OK, or 'FAIL:' followed by the reason." \
  2>/dev/null)

if echo "$RESULT" | grep -q "^PASS"; then
  exit 0
fi

echo "$RESULT" >&2
exit 1
```

This gives you an independent evaluator with a fresh context — no self-evaluation bias.

### Environment variables

Verify commands receive these environment variables:

| Variable | Example | Description |
|----------|---------|-------------|
| `TKA_TICKET_ID` | `myproj-003` | Ticket ID |
| `TKA_TICKET_PROJECT` | `myproj` | Project name |
| `TKA_TICKET_SEQ` | `3` | Sequence number |
| `TKA_TICKET_STATUS` | `red` | Current status (source) |
| `TKA_TRANSITION_TO` | `green` | Target status |
| `TKA_BASE_PATH` | `/path/to/.tka` | Resolved .tka directory |

`TKA_BASE_PATH` is also used for `.tka` resolution: `--base` > `TKA_BASE_PATH` > `./.tka` > parent directory search. This means verify scripts that spawn sub-agents can pass the tka context through automatically.

## Example: tka-dev — How tka Develops Itself

tka uses itself for its own development. The `tka-dev` project is a real workflow that automates git worktree setup, testing, AI code review, and GitHub releases — all through verify scripts.

### Project definition

```yaml
states:
  initial: todo
  transitions:
    todo:
      targets: [implementing]
      verify:
        implementing: "./scripts/setup-worktree.sh"
    implementing: [testing]
    testing:
      targets: [done]
      verify:
        done: "./scripts/verify-done.sh"
    done:
      targets: [released]
      verify:
        released: "./scripts/release.sh"
```

### What each verify does

**`setup-worktree.sh`** (todo → implementing)
Creates a git worktree at `/tmp/<ticket-id>` so each ticket gets an isolated branch. The worktree path is saved to the ticket's `worktree` field.

**`verify-done.sh`** (testing → done)
Runs inside the worktree and checks:
1. No uncommitted changes
2. `pubspec.yaml` version bumped from main
3. Valid semver format
4. `dart test` passes
5. `dart analyze --fatal-infos` passes
6. AI code review via `claude -p` (independent context, no self-evaluation bias)

**`release.sh`** (done → released)
Merges the ticket branch into main, pushes a version tag, and cleans up the worktree. GitHub Actions picks up the tag and creates a release with cross-platform binaries.

### Full lifecycle

```bash
tka create tka-dev --set title="Fix parsing bug"
# → tka-dev-005 created

tka transition tka-dev-005 --to implementing
# → setup-worktree.sh creates /tmp/tka-dev-005 branch
# → Agent works in the worktree

tka transition tka-dev-005 --to testing
# → Agent considers the implementation complete

tka transition tka-dev-005 --to done
# → verify-done.sh runs tests, analyze, AI review
# → Blocked if anything fails — agent reads error and self-corrects

tka transition tka-dev-005 --to released
# → release.sh merges to main, pushes tag
# → CI builds binaries, creates GitHub release
```

The agent never skips a step. Verify gates enforce quality without human oversight.

## Schema Definition

Projects are defined by fields and a state machine. Use `tka project schema` to get the full spec, then pass JSON to `--schema`:

```bash
# Get the spec
tka project schema

# Create a project
tka project add bugs --schema '{
  "description": "Bug tracker",
  "fields": {
    "title":    {"type": "string", "required": true},
    "severity": {"type": "enum", "values": ["critical", "major", "minor"]},
    "detail":   {"type": "string"},
    "history":  {"type": "list"}
  },
  "states": {
    "initial": "open",
    "transitions": {
      "open": ["investigating"],
      "investigating": ["fixing", "wontfix"],
      "fixing": ["verifying"],
      "verifying": ["done", "fixing"]
    }
  }
}'
```

**Field types**: `string`, `number`, `date` (YYYY-MM-DD), `list` (append-only), `enum` (requires `values`)

**States**: Keys in `transitions` are non-terminal. States that only appear as targets (like `done` above) are terminal — no further transitions allowed.

## Directory Structure

`tka init` creates a `.tka/` directory in your project root:

```
.tka/
├── projects/          # Project definitions (YAML)
│   ├── my-tasks.yaml
│   └── archived/      # Archived projects
└── data/              # Ticket data (JSON, one file per ticket)
    ├── my-tasks/
    │   ├── 001.json
    │   ├── 002.json
    │   └── archived/  # Archived tickets
    └── ...
```

Everything is plain files — no database, no server. Check `.tka/` into version control if you want history, or `.gitignore` it if you don't.

## Build

```bash
make          # Build
make install  # Install to ~/.local/bin
make test     # Run tests
```

## License

[MIT](LICENSE)
