import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../helpers/field_input.dart';
import '../helpers/ticket_id.dart';
import '../models/field_definition.dart';
import '../models/ticket.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import '../validators/schema_validator.dart';
import '../validators/transition_validator.dart';

class TransitionCommand extends Command<void> {
  @override
  final String name = 'transition';
  @override
  final String description = '''Transition ticket to a new status.

Usage: tka transition <id> --to <status> [--set field=value ...] [--append field=value ...]
Only transitions defined in the project state machine are allowed.
If the transition has a "verify" command, it runs before transitioning.
The transition is blocked if the command exits with non-zero.
Field updates via --set/--append are applied after verify passes.
See "tka project schema" for verify definition and available environment variables.
Output: {"id": "...", "from": "...", "to": "...", "guide?": "..."}''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final String? basePath;
  final IOSink _out;

  TransitionCommand({
    required this.projectStore,
    required this.ticketStore,
    this.basePath,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser
      ..addOption('to', help: 'Target status', mandatory: true)
      ..addMultiOption('set',
          abbr: 's',
          help: 'Set field value (field=value)',
          splitCommas: false)
      ..addMultiOption('append',
          abbr: 'a',
          help: 'Append to list field (field=value)',
          splitCommas: false);
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
    final targetStatus = argResults!['to'] as String;
    final setOptions = argResults!['set'] as List<String>;
    final appendOptions = argResults!['append'] as List<String>;

    final error = TransitionValidator.validate(
        projectDef.stateMachine, ticket.status, targetStatus);
    if (error != null) {
      throw Exception(error);
    }

    // Validate --set and --append options early (before verify)
    Map<String, dynamic>? changedFields;
    if (setOptions.isNotEmpty) {
      changedFields = buildFieldsFromSetOptions(setOptions, projectDef.fields);
    }

    final appendEntries = <String, String>{};
    for (final opt in appendOptions) {
      final (name, rawValue) = parseSetOption(opt);
      final fieldDef = projectDef.fields[name];
      if (fieldDef == null) {
        throw Exception(
            'Field "$name" is not defined in project ${ticket.project}');
      }
      if (fieldDef.type != FieldType.list) {
        throw Exception(
            'Field "$name" is not a list type (got ${fieldDef.type.name})');
      }
      final value = resolveFieldValue(rawValue)!;
      if (value.isEmpty) {
        throw Exception('Append value for "$name" cannot be empty.');
      }
      appendEntries[name] = value;
    }

    String? verifyOutput;
    final verifyCmd =
        projectDef.stateMachine.getVerify(ticket.status, targetStatus);
    if (verifyCmd != null) {
      final env = {
        'TKA_TICKET_ID': ticket.id,
        'TKA_TICKET_PROJECT': ticket.project,
        'TKA_TICKET_SEQ': ticket.seq.toString(),
        'TKA_TICKET_STATUS': ticket.status,
        'TKA_TRANSITION_TO': targetStatus,
        'TKA_BASE_PATH': ?basePath,
      };
      final workDir = basePath != null ? p.dirname(basePath!) : null;
      final result = Platform.isWindows
          ? Process.runSync('cmd', ['/c', verifyCmd],
              environment: env, workingDirectory: workDir)
          : Process.runSync('sh', ['-c', verifyCmd],
              environment: env, workingDirectory: workDir);
      final combinedOutput = [
        (result.stdout as String).trim(),
        (result.stderr as String).trim(),
      ].where((s) => s.isNotEmpty).join('\n');
      if (combinedOutput.isNotEmpty) {
        verifyOutput = combinedOutput;
      }
      if (result.exitCode != 0) {
        throw Exception(jsonEncode({
          'error': 'Verify failed for transition ${ticket.status} → $targetStatus. '
              'Command: $verifyCmd (exit code ${result.exitCode}).',
          'output': ?verifyOutput,
        }));
      }
    }

    // Reload ticket in case verify script modified it
    final current = ticketStore.load(project, seq);

    // Apply --set and --append field changes after verify passes
    final newFields = Map<String, dynamic>.from(current.fields);
    if (changedFields != null) {
      newFields.addAll(changedFields);
    }
    for (final entry in appendEntries.entries) {
      final existing = newFields[entry.key];
      final list =
          existing is List ? List<dynamic>.from(existing) : <dynamic>[];
      list.add(entry.value);
      newFields[entry.key] = list;
    }

    // Validate merged fields
    if (changedFields != null || appendEntries.isNotEmpty) {
      final errors =
          SchemaValidator.validate(newFields, projectDef.fields);
      if (errors.isNotEmpty) {
        throw Exception('Validation errors:\n${errors.join('\n')}');
      }
    }

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final currentJson = current.toJson();
    final updated = Ticket(
      project: current.project,
      seq: current.seq,
      status: targetStatus,
      fields: newFields,
      createdAt: current.createdAt,
      updatedAt: now,
      createdAtRaw: currentJson['created_at'] as String,
      updatedAtRaw: nowStr,
    );

    ticketStore.save(updated,
        expectedUpdatedAt: currentJson['updated_at'] as String);
    final resultJson = <String, dynamic>{
      'id': ticket.id,
      'from': ticket.status,
      'to': targetStatus,
    };
    if (verifyOutput != null) {
      resultJson['output'] = verifyOutput;
    }
    final guide = projectDef.stateMachine.getGuide(targetStatus);
    if (guide != null) {
      resultJson['guide'] = guide;
    }
    _out.writeln(jsonEncode(resultJson));
  }
}
