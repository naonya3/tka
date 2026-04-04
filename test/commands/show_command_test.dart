import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/show_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/ticket_store.dart';

Ticket _makeTicket(String project, int seq, String status,
    {Map<String, dynamic>? fields}) {
  return Ticket(
    project: project,
    seq: seq,
    status: status,
    fields: fields ?? {'title': 'ticket $seq'},
    createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
    updatedAt: DateTime.parse('2026-04-02T14:30:00+09:00'),
    createdAtRaw: '2026-04-01T10:00:00+09:00',
    updatedAtRaw: '2026-04-02T14:30:00+09:00',
  );
}

void main() {
  late Directory tmpDir;
  late TicketStore ticketStore;
  late _TestSink out;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('show_cmd_test_');
    ticketStore = TicketStore(tmpDir.path);
    out = _TestSink();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  CommandRunner<void> _makeRunner() {
    final runner = CommandRunner<void>('ticket', 'test');
    runner.addCommand(ShowCommand(ticketStore: ticketStore, out: out));
    return runner;
  }

  Map<String, dynamic> _parseOutput() {
    return jsonDecode(out.lines.join('')) as Map<String, dynamic>;
  }

  group('show command', () {
    test('outputs ticket as JSON', () async {
      ticketStore.save(_makeTicket('myproj', 3, 'in_progress',
          fields: {'title': 'Implement feature', 'detail': 'Some detail'}));

      await _makeRunner().run(['show', 'myproj-003']);
      final result = _parseOutput();
      expect(result['id'], equals('myproj-003'));
      expect(result['project'], equals('myproj'));
      expect(result['status'], equals('in_progress'));
      expect(result['fields']['title'], equals('Implement feature'));
      expect(result['fields']['detail'], equals('Some detail'));
      expect(result['created_at'], equals('2026-04-01T10:00:00+09:00'));
      expect(result['updated_at'], equals('2026-04-02T14:30:00+09:00'));
    });

    test('handles hyphenated project names', () async {
      ticketStore.save(_makeTicket('game-dev', 1, 'backlog',
          fields: {'title': 'Setup'}));

      await _makeRunner().run(['show', 'game-dev-001']);
      final result = _parseOutput();
      expect(result['id'], equals('game-dev-001'));
      expect(result['project'], equals('game-dev'));
    });

    test('includes list fields in JSON', () async {
      ticketStore.save(_makeTicket('proj', 1, 'todo', fields: {
        'title': 'Test',
        'history': ['entry 1', 'entry 2'],
      }));

      await _makeRunner().run(['show', 'proj-001']);
      final result = _parseOutput();
      expect(result['fields']['history'], equals(['entry 1', 'entry 2']));
    });

    test('throws on missing id argument', () async {
      expect(
        () => _makeRunner().run(['show']),
        throwsA(isA<UsageException>()),
      );
    });

    test('throws on non-existing ticket', () async {
      expect(
        () => _makeRunner().run(['show', 'proj-999']),
        throwsException,
      );
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
