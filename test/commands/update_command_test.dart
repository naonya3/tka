import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/update_command.dart';
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
    tmpDir = Directory.systemTemp.createTempSync('update_cmd_test_');
    final projectsDir = Directory('${tmpDir.path}/projects');
    projectsDir.createSync(recursive: true);
    final dataDir = Directory('${tmpDir.path}/data');
    dataDir.createSync(recursive: true);

    File('${projectsDir.path}/test-project.yaml').writeAsStringSync('''
version: 1
name: test-project
description: test
fields:
  title: { type: string, required: true }
  detail: { type: string }
  due: { type: date }
  quantity: { type: number }
  history: { type: list }
states:
  initial: todo
  transitions:
    todo: [done]
''');

    projectStore = ProjectStore(projectsDir.path);
    ticketStore = TicketStore(dataDir.path);

    final ticket = Ticket(
      project: 'test-project',
      seq: 1,
      status: 'todo',
      fields: {'title': 'Original title', 'detail': 'Original detail'},
      createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      createdAtRaw: '2026-04-01T10:00:00+09:00',
      updatedAtRaw: '2026-04-01T10:00:00+09:00',
    );
    ticketStore.save(ticket);

    out = TestSink();
    runner = CommandRunner<void>('ticket', 'test')
      ..addCommand(UpdateCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out,
      ));
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('updates title field with --set', () async {
    await runner
        .run(['update', 'test-project-001', '--set', 'title=New title']);
    final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
    expect(json['id'], equals('test-project-001'));
    expect(json['updated_at'], isA<String>());

    final loaded = ticketStore.load('test-project', 1);
    expect(loaded.fields['title'], equals('New title'));
    expect(loaded.fields['detail'], equals('Original detail'));
  });

  test('updates multiple fields with --set', () async {
    await runner.run([
      'update',
      'test-project-001',
      '--set',
      'title=New title',
      '--set',
      'detail=New detail',
    ]);

    final loaded = ticketStore.load('test-project', 1);
    expect(loaded.fields['title'], equals('New title'));
    expect(loaded.fields['detail'], equals('New detail'));
  });

  test('throws when no --set provided', () async {
    expect(
      () => runner.run(['update', 'test-project-001']),
      throwsA(isA<UsageException>()),
    );
  });

  test('throws when no ticket id provided', () async {
    expect(
      () => runner.run(['update']),
      throwsA(isA<UsageException>()),
    );
  });

  test('validates schema on update', () async {
    expect(
      () => runner
          .run(['update', 'test-project-001', '--set', 'due=not-a-date']),
      throwsException,
    );
  });

  test('coerces number field', () async {
    await runner
        .run(['update', 'test-project-001', '--set', 'quantity=42']);

    final loaded = ticketStore.load('test-project', 1);
    expect(loaded.fields['quantity'], equals(42));
  });

  test('preserves createdAt on update', () async {
    await runner
        .run(['update', 'test-project-001', '--set', 'title=Changed']);
    final loaded = ticketStore.load('test-project', 1);
    final json = loaded.toJson();
    expect(json['created_at'], equals('2026-04-01T10:00:00+09:00'));
  });
}
