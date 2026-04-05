import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/show_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/project_store.dart';
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

  CommandRunner<void> makeRunner() {
    final runner = CommandRunner<void>('ticket', 'test');
    runner.addCommand(ShowCommand(ticketStore: ticketStore, out: out));
    return runner;
  }

  Map<String, dynamic> parseOutput() {
    return jsonDecode(out.lines.join('')) as Map<String, dynamic>;
  }

  group('show command', () {
    test('outputs ticket as JSON', () async {
      ticketStore.save(_makeTicket('myproj', 3, 'in_progress',
          fields: {'title': 'Implement feature', 'detail': 'Some detail'}));

      await makeRunner().run(['show', 'myproj-003']);
      final result = parseOutput();
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

      await makeRunner().run(['show', 'game-dev-001']);
      final result = parseOutput();
      expect(result['id'], equals('game-dev-001'));
      expect(result['project'], equals('game-dev'));
    });

    test('includes list fields in JSON', () async {
      ticketStore.save(_makeTicket('proj', 1, 'todo', fields: {
        'title': 'Test',
        'history': ['entry 1', 'entry 2'],
      }));

      await makeRunner().run(['show', 'proj-001']);
      final result = parseOutput();
      expect(result['fields']['history'], equals(['entry 1', 'entry 2']));
    });

    test('throws on missing id argument', () async {
      expect(
        () => makeRunner().run(['show']),
        throwsA(isA<UsageException>()),
      );
    });

    test('throws on non-existing ticket', () async {
      expect(
        () => makeRunner().run(['show', 'proj-999']),
        throwsException,
      );
    });
  });

  group('show command with project store', () {
    late Directory projectDir;

    setUp(() {
      projectDir = Directory('${tmpDir.path}/projects');
      projectDir.createSync();
    });

    CommandRunner<void> makeRunnerWithProject() {
      final projectStore = ProjectStore(projectDir.path);
      final runner = CommandRunner<void>('ticket', 'test');
      runner.addCommand(ShowCommand(
        ticketStore: ticketStore,
        projectStore: projectStore,
        out: out,
      ));
      return runner;
    }

    test('available_transitions lists target states', () async {
      File('${projectDir.path}/myproj.yaml').writeAsStringSync('''
version: 1
name: myproj
description: test project
fields:
  title:
    type: string
    required: true
states:
  initial: todo
  transitions:
    todo: [implementing, cancelled]
    implementing: [done]
''');
      ticketStore.save(_makeTicket('myproj', 1, 'todo'));

      await makeRunnerWithProject().run(['show', 'myproj-001']);
      final result = parseOutput();
      expect(result['available_transitions'], equals(['implementing', 'cancelled']));
    });

    test('guide is included in output when set', () async {
      File('${projectDir.path}/myproj.yaml').writeAsStringSync('''
version: 1
name: myproj
description: test project
fields:
  title:
    type: string
    required: true
states:
  initial: todo
  guide:
    todo: "未着手。implementingに遷移して開始"
    implementing: "worktree内でコードを書く"
  transitions:
    todo: [implementing]
    implementing: [done]
''');
      ticketStore.save(_makeTicket('myproj', 1, 'todo'));

      await makeRunnerWithProject().run(['show', 'myproj-001']);
      final result = parseOutput();
      expect(result['guide'], equals('未着手。implementingに遷移して開始'));
    });

    test('guide is omitted when not set for current status', () async {
      File('${projectDir.path}/myproj.yaml').writeAsStringSync('''
version: 1
name: myproj
description: test project
fields:
  title:
    type: string
    required: true
states:
  initial: todo
  guide:
    implementing: "worktree内でコードを書く"
  transitions:
    todo: [implementing]
    implementing: [done]
''');
      ticketStore.save(_makeTicket('myproj', 1, 'todo'));

      await makeRunnerWithProject().run(['show', 'myproj-001']);
      final result = parseOutput();
      expect(result.containsKey('guide'), isFalse);
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
