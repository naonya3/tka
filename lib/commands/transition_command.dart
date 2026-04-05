import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
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
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final currentJson = current.toJson();
    final updated = Ticket(
      project: current.project,
      seq: current.seq,
      status: targetStatus,
      fields: current.fields,
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
