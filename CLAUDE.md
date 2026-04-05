# tka

Schema-driven ticket management CLI for AI agents.

## Tech Stack

- **Language**: Dart
- **Data store**: JSON files (1 ticket = 1 file)
- **Project definitions**: YAML
- **Dependencies**: `args`, `yaml`, `path`
- **Build**: `make && make install` -> `~/.local/bin/tka`
- **Test**: `dart test`

## Workflow

Before starting work on a ticket, run `tka project workflow <project>` to understand the project's state machine, guides, and transition rules. Follow the guides at each state.

## Development Rules

- Ticket-driven, TDD (Red -> Green -> Refactor)
- Keep tickets small (1 ticket = 1 function or 1 class)
- Prioritize AI efficiency over human readability
- Commit messages in English
