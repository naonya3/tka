import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/append_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/project_store.dart';
import 'package:tka/store/ticket_store.dart';
import '../test_helpers.dart';

void main() {
  late Directory tmpDir;
  late ProjectStore projectStore;
  late TicketStore ticketStore;
  late CommandRunner<void> runner;
  late TestSink out;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('append_cmd_test_');
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
  detail: { type: string }
  history: { type: list }
states:
  initial: backlog
  transitions:
    backlog: [in_progress]
''');

    projectStore = ProjectStore(projectsDir.path);
    ticketStore = TicketStore(dataDir.path);

    final ticket = Ticket(
      project: 'game-dev',
      seq: 1,
      status: 'backlog',
      fields: {'title': 'Test ticket', 'history': ['Initial entry']},
      createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      createdAtRaw: '2026-04-01T10:00:00+09:00',
      updatedAtRaw: '2026-04-01T10:00:00+09:00',
    );
    ticketStore.save(ticket);

    out = TestSink();
    runner = CommandRunner<void>('ticket', 'test')
      ..addCommand(AppendCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out,
      ));
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('appends to existing list field', () async {
    await runner.run([
      'append',
      'game-dev-001',
      '--field',
      'history',
      '--value',
      'Second entry'
    ]);
    final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
    expect(json['id'], equals('game-dev-001'));
    expect(json['field'], equals('history'));
    expect(json['count'], equals(2));

    final loaded = ticketStore.load('game-dev', 1);
    final history = loaded.fields['history'] as List;
    expect(history.length, equals(2));
    expect(history[0], equals('Initial entry'));
    expect(history[1], equals('Second entry'));
  });

  test('creates list if field is null', () async {
    // Save ticket without history field
    final ticket = Ticket(
      project: 'game-dev',
      seq: 2,
      status: 'backlog',
      fields: {'title': 'No history ticket'},
      createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      createdAtRaw: '2026-04-01T10:00:00+09:00',
      updatedAtRaw: '2026-04-01T10:00:00+09:00',
    );
    ticketStore.save(ticket);

    await runner.run([
      'append',
      'game-dev-002',
      '--field',
      'history',
      '--value',
      'First entry'
    ]);

    final loaded = ticketStore.load('game-dev', 2);
    final history = loaded.fields['history'] as List;
    expect(history.length, equals(1));
    expect(history[0], equals('First entry'));
  });

  test('rejects non-list field', () async {
    expect(
      () => runner.run([
        'append',
        'game-dev-001',
        '--field',
        'title',
        '--value',
        'nope'
      ]),
      throwsException,
    );
  });

  test('rejects undefined field', () async {
    expect(
      () => runner.run([
        'append',
        'game-dev-001',
        '--field',
        'nonexistent',
        '--value',
        'nope'
      ]),
      throwsException,
    );
  });

  test('throws when no ticket id provided', () async {
    expect(
      () => runner.run(['append', '--field', 'history', '--value', 'x']),
      throwsA(isA<UsageException>()),
    );
  });
}
