import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/ticket_id.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';

class ShowCommand extends Command<void> {
  @override
  final String name = 'show';
  @override
  final String description = '''Show ticket details.

Usage: tka show <id>  (e.g. tka show shopping-001)
       tka show <id> --field <name>  (raw field value, not JSON)
Output: compact JSON (one line). Includes available_transitions for current status.
Use --pretty for indented output.
Use --field to get a single field value as raw text (lists output as JSON array).
--field accepts any built-in (id, project, seq, title, status, created_at, updated_at) or custom field. Unknown names error with the available list.''';

  final ProjectStore? projectStore;
  final TicketStore ticketStore;
  final IOSink _out;

  ShowCommand({
    this.projectStore,
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser
      ..addFlag('pretty',
          help: 'Pretty-print JSON output', defaultsTo: false)
      ..addOption('field',
          abbr: 'f', help: 'Output a single field value as raw text');
  }

  @override
  void run() {
    final args = argResults!.rest;
    if (args.isEmpty) {
      usageException('Please provide a ticket id (e.g., game-dev-003)');
    }

    final rawId = args.first;
    final (project, seq) = _parseIdOrUsageError(rawId);

    final ticket = ticketStore.load(project, seq);

    // --field mode: output raw field value
    final fieldName = argResults!['field'] as String?;
    if (fieldName != null) {
      const builtIns = {
        'id', 'project', 'seq', 'title', 'status', 'created_at', 'updated_at',
      };
      Set<String>? schemaFields;
      if (projectStore != null) {
        try {
          schemaFields = projectStore!.load(ticket.project).fields.keys.toSet();
        } catch (_) {
          schemaFields = null;
        }
      }
      final isKnown = builtIns.contains(fieldName) ||
          (schemaFields != null
              ? schemaFields.contains(fieldName)
              : ticket.fields.containsKey(fieldName));
      if (!isKnown) {
        final available = [
          ...builtIns,
          ...?schemaFields,
          if (schemaFields == null) ...ticket.fields.keys,
        ]..sort();
        throw Exception(
            'Unknown field: $fieldName. Available: ${available.join(', ')}');
      }
      final dynamic value = builtIns.contains(fieldName)
          ? ticket.toJson()[fieldName]
          : ticket.fields[fieldName];
      if (value == null) {
        _out.writeln('');
      } else if (value is List) {
        _out.writeln(jsonEncode(value));
      } else {
        _out.writeln(value.toString());
      }
      return;
    }

    final json = ticket.toJson();

    if (projectStore != null) {
      try {
        final def = projectStore!.load(ticket.project);
        final guide = def.stateMachine.getGuide(ticket.status);
        if (guide != null) json['guide'] = guide;
        final targets = def.stateMachine.getAvailableTransitions(ticket.status);
        json['available_transitions'] = targets.map((to) => to).toList();
      } catch (_) {
        json['available_transitions'] = <Map<String, dynamic>>[];
      }
    }

    final pretty = argResults!['pretty'] as bool;
    if (pretty) {
      _out.writeln(const JsonEncoder.withIndent('  ').convert(json));
    } else {
      _out.writeln(jsonEncode(json));
    }
  }

  (String, int) _parseIdOrUsageError(String rawId) {
    try {
      return parseTicketId(rawId);
    } on FormatException {
      usageException('Invalid ticket id format: $rawId');
    }
  }
}
