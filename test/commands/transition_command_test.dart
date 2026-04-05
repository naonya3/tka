import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/transition_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/project_store.dart';
import 'package:tka/store/ticket_store.dart';

void main() {
  late Directory tmpDir;
  late ProjectStore projectStore;
  late TicketStore ticketStore;
  late CommandRunner<void> runner;
  late StringBuffer output;
  late IOSink sink;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('transition_cmd_test_');
    final projectsDir = Directory('${tmpDir.path}/projects');
    projectsDir.createSync(recursive: true);
    final dataDir = Directory('${tmpDir.path}/data');
    dataDir.createSync(recursive: true);

    File('${projectsDir.path}/game-dev.yaml').writeAsStringSync('''
version: 1
name: game-dev
description: test
fields:
  title: { type: string, required: true }
states:
  initial: backlog
  transitions:
    backlog: [in_progress]
    in_progress: [review, blocked]
    blocked: [in_progress]
    review: [done, in_progress]
''');

    projectStore = ProjectStore(projectsDir.path);
    ticketStore = TicketStore(dataDir.path);

    final ticket = Ticket(
      project: 'game-dev',
      seq: 1,
      status: 'backlog',
      fields: {'title': 'Test ticket'},
      createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      createdAtRaw: '2026-04-01T10:00:00+09:00',
      updatedAtRaw: '2026-04-01T10:00:00+09:00',
    );
    ticketStore.save(ticket);

    output = StringBuffer();
    sink = IOSink(_StringSink(output));
    runner = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: sink,
      ));
  });

  tearDown(() {
    sink.close();
    tmpDir.deleteSync(recursive: true);
  });

  test('transitions ticket to valid status', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final json = jsonDecode(output.toString().trim()) as Map<String, dynamic>;
    expect(json['id'], equals('game-dev-001'));
    expect(json['from'], equals('backlog'));
    expect(json['to'], equals('in_progress'));

    final loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('in_progress'));
  });

  test('rejects invalid transition', () async {
    expect(
      () => runner.run(['transition', 'game-dev-001', '--to', 'done']),
      throwsException,
    );

    final loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('backlog'));
  });

  test('rejects transition from terminal state', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);

    // Save with new status so we can transition further
    var loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('in_progress'));

    // Create a new runner with fresh sink
    final output2 = StringBuffer();
    final sink2 = IOSink(_StringSink(output2));
    final runner2 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: sink2,
      ));

    await runner2.run(['transition', 'game-dev-001', '--to', 'review']);
    loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('review'));

    final output3 = StringBuffer();
    final sink3 = IOSink(_StringSink(output3));
    final runner3 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: sink3,
      ));

    await runner3.run(['transition', 'game-dev-001', '--to', 'done']);
    loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('done'));

    // done is terminal
    final output4 = StringBuffer();
    final sink4 = IOSink(_StringSink(output4));
    final runner4 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: sink4,
      ));

    expect(
      () => runner4.run(['transition', 'game-dev-001', '--to', 'backlog']),
      throwsException,
    );
    sink2.close();
    sink3.close();
    sink4.close();
  });

  test('throws when no ticket id provided', () async {
    expect(
      () => runner.run(['transition', '--to', 'in_progress']),
      throwsA(isA<UsageException>()),
    );
  });

  group('verify', () {
    late Directory verifyTmpDir;
    late ProjectStore verifyProjectStore;
    late TicketStore verifyTicketStore;

    setUp(() {
      verifyTmpDir = Directory.systemTemp.createTempSync('verify_test_');
      final projectsDir = Directory('${verifyTmpDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${verifyTmpDir.path}/data');
      dataDir.createSync(recursive: true);

      File('${projectsDir.path}/tdd.yaml').writeAsStringSync('''
version: 1
name: tdd
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo: [red]
    red:
      targets: [green]
      verify:
        green: "true"
    green: [done]
''');

      verifyProjectStore = ProjectStore(projectsDir.path);
      verifyTicketStore = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'tdd',
        seq: 1,
        status: 'red',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket);
    });

    tearDown(() {
      verifyTmpDir.deleteSync(recursive: true);
    });

    test('transition succeeds when verify command passes', () async {
      final buf = StringBuffer();
      final s = IOSink(_StringSink(buf));
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: s,
        ));
      await r.run(['transition', 'tdd-001', '--to', 'green']);
      final json = jsonDecode(buf.toString().trim()) as Map<String, dynamic>;
      expect(json['to'], equals('green'));

      final loaded = verifyTicketStore.load('tdd', 1);
      expect(loaded.status, equals('green'));
      s.close();
    });

    test('verify command receives TKA environment variables', () async {
      // Create project with verify that checks env vars
      File('${verifyTmpDir.path}/projects/envcheck.yaml').writeAsStringSync('''
version: 1
name: envcheck
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo:
      targets: [done]
      verify:
        done: "test -n \\"\$TKA_TICKET_ID\\" && test -n \\"\$TKA_BASE_PATH\\""
''');

      final ticket = Ticket(
        project: 'envcheck',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket);

      final buf = StringBuffer();
      final s = IOSink(_StringSink(buf));
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          basePath: verifyTmpDir.path,
          out: s,
        ));
      await r.run(['transition', 'envcheck-001', '--to', 'done']);
      final json = jsonDecode(buf.toString().trim()) as Map<String, dynamic>;
      expect(json['to'], equals('done'));
      s.close();
    });

    test('transition fails when verify command fails', () async {
      // Create project with failing verify
      File('${verifyTmpDir.path}/projects/fail.yaml').writeAsStringSync('''
version: 1
name: fail
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo:
      targets: [done]
      verify:
        done: "false"
''');

      final ticket = Ticket(
        project: 'fail',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket);

      final buf = StringBuffer();
      final s = IOSink(_StringSink(buf));
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: s,
        ));

      expect(
        () => r.run(['transition', 'fail-001', '--to', 'done']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Verify failed'))),
      );

      // Ticket should NOT have transitioned
      final loaded = verifyTicketStore.load('fail', 1);
      expect(loaded.status, equals('todo'));
      s.close();
    });

    test('transition without verify proceeds normally', () async {
      // First transition to red (no verify on todo->red)
      final ticket0 = Ticket(
        project: 'tdd',
        seq: 2,
        status: 'todo',
        fields: {'title': 'No verify'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket0);

      final buf = StringBuffer();
      final s = IOSink(_StringSink(buf));
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: s,
        ));
      await r.run(['transition', 'tdd-002', '--to', 'red']);
      final loaded = verifyTicketStore.load('tdd', 2);
      expect(loaded.status, equals('red'));
      s.close();
    });
  });

  test('updates updatedAt on transition', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final loaded = ticketStore.load('game-dev', 1);
    final json = loaded.toJson();
    expect(json['updated_at'], isNot(equals('2026-04-01T10:00:00+09:00')));
    expect(json['created_at'], equals('2026-04-01T10:00:00+09:00'));
  });
}

class _StringSink implements StreamConsumer<List<int>> {
  final StringBuffer _buffer;
  _StringSink(this._buffer);

  @override
  Future addStream(Stream<List<int>> stream) {
    final completer = stream.listen((data) {
      _buffer.write(utf8.decode(data));
    });
    return completer.asFuture();
  }

  @override
  Future close() async {}
}
