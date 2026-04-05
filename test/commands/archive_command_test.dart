import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/archive_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/ticket_store.dart';

Ticket _makeTicket(String project, int seq, String status) {
  final now = DateTime.now();
  final nowStr = now.toIso8601String();
  return Ticket(
    project: project,
    seq: seq,
    status: status,
    fields: {'title': 'ticket $seq'},
    createdAt: now,
    updatedAt: now,
    createdAtRaw: nowStr,
    updatedAtRaw: nowStr,
  );
}

void main() {
  late Directory tmpDir;
  late TicketStore ticketStore;
  late _TestSink out;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('archive_cmd_test_');
    ticketStore = TicketStore(tmpDir.path);
    out = _TestSink();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  CommandRunner<void> makeRunner() {
    final runner = CommandRunner<void>('ticket', 'test');
    runner.addCommand(ArchiveCommand(ticketStore: ticketStore, out: out));
    return runner;
  }

  group('archive command', () {
    test('archives a ticket and outputs JSON', () async {
      ticketStore.save(_makeTicket('proj', 1, 'done'));

      await makeRunner().run(['archive', 'proj-001']);
      final result = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(result['id'], equals('proj-001'));
      expect(result['archived'], isTrue);
    });

    test('archived ticket is no longer in active list', () async {
      ticketStore.save(_makeTicket('proj', 1, 'done'));

      await makeRunner().run(['archive', 'proj-001']);
      expect(ticketStore.listAll('proj'), isEmpty);
    });

    test('archived ticket appears in archived list', () async {
      ticketStore.save(_makeTicket('proj', 1, 'done'));

      await makeRunner().run(['archive', 'proj-001']);
      final archived = ticketStore.listArchived('proj');
      expect(archived, hasLength(1));
      expect(archived.first.seq, equals(1));
    });

    test('throws on missing id argument', () async {
      expect(
        () => makeRunner().run(['archive']),
        throwsA(isA<UsageException>()),
      );
    });

    test('throws on non-existing ticket', () async {
      expect(
        () => makeRunner().run(['archive', 'proj-999']),
        throwsException,
      );
    });

    test('throws on invalid id format', () async {
      expect(
        () => makeRunner().run(['archive', 'nohyphen']),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles hyphenated project names', () async {
      ticketStore.save(_makeTicket('game-dev', 1, 'done'));

      await makeRunner().run(['archive', 'game-dev-001']);
      final result = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(result['id'], equals('game-dev-001'));
      expect(result['archived'], isTrue);
      expect(ticketStore.listAll('game-dev'), isEmpty);
    });
  });
}

class _TestSink implements IOSink {
  final List<String> lines = [];

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  void write(Object? object) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
