import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/ticket_id.dart';
import '../models/ticket.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import '../validators/transition_validator.dart';

class TransitionCommand extends Command<void> {
  @override
  final String name = 'transition';
  @override
  final String description = '''Transition ticket to a new status.

Usage: tka transition <id> --to <status>
Only transitions defined in the project state machine are allowed.
If the transition has a "verify" command, it runs before transitioning.
The transition is blocked if the command exits with non-zero.
See "tka project schema" for verify definition and available environment variables.
Output: {"id": "...", "from": "...", "to": "..."}''';

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
    argParser.addOption('to', help: 'Target status', mandatory: true);
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

    final error = TransitionValidator.validate(
        projectDef.stateMachine, ticket.status, targetStatus);
    if (error != null) {
      throw Exception(error);
    }

    final verifyCmd =
        projectDef.stateMachine.getVerify(ticket.status, targetStatus);
    if (verifyCmd != null) {
      final env = {
        'TKA_TICKET_ID': ticket.id,
        'TKA_TICKET_PROJECT': ticket.project,
        'TKA_TICKET_SEQ': ticket.seq.toString(),
        'TKA_TICKET_STATUS': ticket.status,
        'TKA_TRANSITION_TO': targetStatus,
        if (basePath != null) 'TKA_BASE_PATH': basePath!,
      };
      final result = Platform.isWindows
          ? Process.runSync('cmd', ['/c', verifyCmd], environment: env)
          : Process.runSync('sh', ['-c', verifyCmd], environment: env);
      if (result.exitCode != 0) {
        final output = (result.stderr as String).isNotEmpty
            ? result.stderr as String
            : result.stdout as String;
        throw Exception(
            'Verify failed for transition ${ticket.status} → $targetStatus. '
            'Command: $verifyCmd (exit code ${result.exitCode}). '
            'Output: ${output.toString().trim()}');
      }
    }

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final oldJson = ticket.toJson();
    final updated = Ticket(
      project: ticket.project,
      seq: ticket.seq,
      status: targetStatus,
      fields: ticket.fields,
      createdAt: ticket.createdAt,
      updatedAt: now,
      createdAtRaw: oldJson['created_at'] as String,
      updatedAtRaw: nowStr,
    );

    ticketStore.save(updated,
        expectedUpdatedAt: oldJson['updated_at'] as String);
    _out.writeln(jsonEncode({
      'id': ticket.id,
      'from': ticket.status,
      'to': targetStatus,
    }));
  }
}
