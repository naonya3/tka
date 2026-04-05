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
Output: compact JSON (one line). Includes available_transitions for current status.
Use --pretty for indented output.''';

  final ProjectStore? projectStore;
  final TicketStore ticketStore;
  final IOSink _out;

  ShowCommand({
    this.projectStore,
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout {
    argParser.addFlag('pretty', help: 'Pretty-print JSON output', defaultsTo: false);
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
