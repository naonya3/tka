import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../helpers/ticket_id.dart';
import '../store/ticket_store.dart';

class ArchiveCommand extends Command<void> {
  @override
  final String name = 'archive';
  @override
  final String description = '''Move a ticket to archived/ directory.

Usage: tka archive <id>
Archived tickets are hidden from list/watch.
Output: {"id": "...", "archived": true}''';

  final TicketStore ticketStore;
  final IOSink _out;

  ArchiveCommand({
    required this.ticketStore,
    IOSink? out,
  }) : _out = out ?? stdout;

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      throw UsageException('Ticket id is required.', usage);
    }
    final id = argResults!.rest.first;
    final (project, seq) = parseTicketId(id);
    ticketStore.archive(project, seq);
    _out.writeln(jsonEncode({'id': id, 'archived': true}));
  }
}
