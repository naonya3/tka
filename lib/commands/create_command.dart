import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../models/field_definition.dart';
import '../models/ticket.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import '../helpers/field_input.dart';
import '../validators/schema_validator.dart';

typedef ProcessStarter = Future<Process> Function(
  String command,
  List<String> args, {
  Map<String, String>? environment,
  ProcessStartMode? mode,
});

class CreateCommand extends Command {
  @override
  final String name = 'create';
  @override
  final String description = '''Create a new ticket.

Usage: tka create <project> --set field=value [--set field=value ...]
Output: {"id": "...", "seq": N}

For long or multiline text, use pipe or file instead of inline value:
  echo "long text..." | tka create proj --set title=Name --set detail=-
  tka create proj --set title=Name --set detail=@path/to/file.txt
If value starts with @, prefix @@ to escape (e.g. --set title=@@handle → @handle).
A @ in the middle of a value is not special and needs no escaping.
Note: always quote --set values in zsh (e.g. --set 'field=value').''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final IOSink _out;
  final String? _basePath;
  final ProcessStarter _processStarter;

  CreateCommand({
    required this.projectStore,
    required this.ticketStore,
    IOSink? out,
    String? basePath,
    ProcessStarter? processStarter,
  })  : _out = out ?? stdout,
        _basePath = basePath,
        _processStarter = processStarter ?? _defaultProcessStarter {
    argParser.addMultiOption('set', abbr: 's', help: 'Set field value (field=value)', splitCommas: false);
  }

  static Future<Process> _defaultProcessStarter(
    String command,
    List<String> args, {
    Map<String, String>? environment,
    ProcessStartMode? mode,
  }) {
    return Process.start(command, args,
        environment: environment, mode: mode ?? ProcessStartMode.normal);
  }

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Project name is required.', usage);
    }
    final projectName = argResults!.rest.first;
    final project = projectStore.load(projectName);

    final setOptions = argResults!['set'] as List<String>;
    final fields = buildFieldsFromSetOptions(setOptions, project.fields);

    final errors = SchemaValidator.validate(fields, project.fields);
    if (errors.isNotEmpty) {
      throw UsageException(
          'Validation errors:\n${errors.join('\n')}', usage);
    }

    for (final entry in project.fields.entries) {
      if (!fields.containsKey(entry.key)) {
        fields[entry.key] = entry.value.type == FieldType.list ? [] : null;
      }
    }

    final placeholder = Ticket(
      project: projectName,
      seq: 0,
      status: project.stateMachine.initial,
      fields: fields,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdAtRaw: '',
      updatedAtRaw: '',
    );

    final seq = ticketStore.createNew(placeholder);
    final id = '$projectName-${seq.toString().padLeft(3, '0')}';
    _out.writeln(jsonEncode({'id': id, 'seq': seq}));

    final onCreateCommand = project.stateMachine.onCreateCommand;
    if (onCreateCommand != null) {
      _processStarter(
        onCreateCommand,
        [],
        environment: {
          'TKA_TICKET_ID': id,
          'TKA_TICKET_PROJECT': projectName,
          'TKA_TICKET_SEQ': seq.toString(),
          'TKA_TICKET_STATUS': project.stateMachine.initial,
          if (_basePath != null) 'TKA_BASE_PATH': _basePath,
        },
        mode: ProcessStartMode.detached,
      );
    }
  }
}
