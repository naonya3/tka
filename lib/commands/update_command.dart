import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/field_input.dart';
import '../helpers/ticket_id.dart';
import '../models/ticket.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import '../validators/schema_validator.dart';

class UpdateCommand extends Command<void> {
  @override
  final String name = 'update';
  @override
  final String description = '''Update ticket fields.

Usage: tka update <id> --set field=value [--set field=value ...]
Output: {"id": "...", "updated_at": "..."}

For long or multiline text, use pipe or file instead of inline value:
  echo "long text..." | tka update <id> --set detail=-
  tka update <id> --set detail=@path/to/file.txt''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final IOSink _out;

  UpdateCommand({
    required this.projectStore,
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser.addMultiOption('set',
        abbr: 's', help: 'Set field value (field=value)', splitCommas: false);
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

    final setOptions = argResults!['set'] as List<String>;
    if (setOptions.isEmpty) {
      throw UsageException('No fields to update.', usage);
    }

    final (newTitle, fieldOptions) = extractTitleFromSetOptions(setOptions);
    final changedFields =
        buildFieldsFromSetOptions(fieldOptions, projectDef.fields);

    final newFields = Map<String, dynamic>.from(ticket.fields);
    newFields.addAll(changedFields);

    final errors = SchemaValidator.validate(newFields, projectDef.fields);
    if (errors.isNotEmpty) {
      throw Exception('Validation errors:\n${errors.join('\n')}');
    }

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final oldJson = ticket.toJson();
    final updated = Ticket(
      project: ticket.project,
      seq: ticket.seq,
      title: newTitle ?? ticket.title,
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
      'updated_at': nowStr,
    }));
  }
}
