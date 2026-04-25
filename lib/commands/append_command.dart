import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/field_input.dart';
import '../helpers/ticket_id.dart';
import '../models/field_definition.dart';
import '../models/ticket.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';

class AppendCommand extends Command<void> {
  @override
  final String name = 'append';
  @override
  final String description = '''Append a value to a list field.

Usage: tka append <id> --field <name> --value <text>
Output: {"id": "...", "field": "...", "count": N}

For long or multiline text, use pipe or file instead of inline value:
  echo "long text..." | tka append <id> --field history --value -
  tka append <id> --field history --value @path/to/file.txt''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final IOSink _out;

  AppendCommand({
    required this.projectStore,
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser
      ..addOption('field', help: 'Field name to append to', mandatory: true)
      ..addOption('value', help: 'Value to append', mandatory: true);
  }

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Ticket id is required.', usage);
    }
    final id = argResults!.rest.first;
    final (project, seq) = parseTicketId(id);

    final ticket = ticketStore.load(project, seq);
    final projectDef = projectStore.load(project);
    final fieldName = argResults!['field'] as String;
    final value = resolveFieldValue(argResults!['value'] as String)!;
    if (value.isEmpty) {
      throw UsageException('Value cannot be empty.', usage);
    }

    final fieldDef = projectDef.fields[fieldName];
    if (fieldDef == null) {
      throw Exception('Field "$fieldName" is not defined in project $project');
    }
    if (fieldDef.type != FieldType.list) {
      throw Exception(
          'Field "$fieldName" is not a list type (got ${fieldDef.type.name})');
    }

    final newFields = Map<String, dynamic>.from(ticket.fields);
    final existing = newFields[fieldName];
    final list =
        existing is List ? List<dynamic>.from(existing) : <dynamic>[];
    list.add(value);
    newFields[fieldName] = list;

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final oldJson = ticket.toJson();
    final updated = Ticket(
      project: ticket.project,
      seq: ticket.seq,
      title: ticket.title,
      status: ticket.status,
      fields: newFields,
      createdAt: ticket.createdAt,
      updatedAt: now,
      createdAtRaw: oldJson['created_at'] as String,
      updatedAtRaw: nowStr,
    );

    ticketStore.save(updated,
        expectedUpdatedAt: oldJson['updated_at'] as String);
    _out.writeln(jsonEncode({
      'id': ticket.id,
      'field': fieldName,
      'count': list.length,
    }));
  }
}
