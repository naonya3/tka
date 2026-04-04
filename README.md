# tka

Ticket for Agents — a schema-driven ticket management CLI.

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
tka project archive <name>                # Archive a project
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
tka show <id>                             # Full ticket JSON + available_transitions
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

## Build

```bash
make          # Build
make install  # Install to ~/.local/bin
make test     # Run tests
```

## License

[MIT](LICENSE)
