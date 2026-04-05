import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/list_command.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/project_store.dart';
import 'package:tka/store/ticket_store.dart';

Ticket _makeTicket(String project, int seq, String status,
    {String? title,
    Map<String, dynamic>? extraFields,
    String? createdAt,
    String? updatedAt}) {
  final fields = <String, dynamic>{'title': title ?? 'ticket $seq'};
  if (extraFields != null) fields.addAll(extraFields);
  final cat = createdAt ?? '2026-04-01T10:00:00+09:00';
  final uat = updatedAt ?? '2026-04-01T10:00:00+09:00';
  return Ticket(
    project: project,
    seq: seq,
    status: status,
    fields: fields,
    createdAt: DateTime.parse(cat),
    updatedAt: DateTime.parse(uat),
    createdAtRaw: cat,
    updatedAtRaw: uat,
  );
}

void _writeProjectYaml(String projectsDir, String name,
    {String? extraFields}) {
  File('$projectsDir/$name.yaml').writeAsStringSync('''
version: 1
name: $name
description: test
fields:
  title: { type: string, required: true }
${extraFields ?? ''}
states:
  initial: todo
  transitions:
    todo: [done]
''');
}

void main() {
  late Directory tmpDir;
  late ProjectStore projectStore;
  late TicketStore ticketStore;
  late _TestSink out;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('list_cmd_test_');
    final projectsDir = '${tmpDir.path}/projects';
    final dataDir = '${tmpDir.path}/data';
    Directory(projectsDir).createSync(recursive: true);
    Directory(dataDir).createSync(recursive: true);
    projectStore = ProjectStore(projectsDir);
    ticketStore = TicketStore(dataDir);
    out = _TestSink();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  CommandRunner<void> makeRunner() {
    final runner = CommandRunner<void>('ticket', 'test');
    runner.addCommand(ListCommand(
      projectStore: projectStore,
      ticketStore: ticketStore,
      out: out,
    ));
    return runner;
  }

  List<dynamic> parseOutput() {
    return jsonDecode(out.lines.join('')) as List<dynamic>;
  }

  group('list command', () {
    test('outputs empty JSON array when no tickets', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      await makeRunner().run(['list', '-p', 'proj']);
      final result = parseOutput();
      expect(result, isEmpty);
    });

    test('lists tickets in project', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'done', title: 'T2'));

      await makeRunner().run(['list', '-p', 'proj']);
      final result = parseOutput();
      expect(result.length, equals(2));
    });

    test('filters by --status', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'done', title: 'T2'));
      ticketStore.save(_makeTicket('proj', 3, 'todo', title: 'T3'));

      await makeRunner().run(['list', '-p', 'proj', '--status', 'todo']);
      final result = parseOutput();
      expect(result.length, equals(2));
      expect(result.every((t) => t['status'] == 'todo'), isTrue);
    });

    test('throws error for unknown status filter', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo'));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--status', 'nonexistent']),
        throwsA(isA<Exception>()),
      );
    });

    test('--limit returns only N tickets', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      for (var i = 1; i <= 5; i++) {
        ticketStore.save(_makeTicket('proj', i, 'todo', title: 'T$i'));
      }

      await makeRunner().run(['list', '-p', 'proj', '--limit', '3']);
      final result = parseOutput();
      expect(result.length, equals(3));
    });

    test('--offset skips first N tickets', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'todo', title: 'T2'));
      ticketStore.save(_makeTicket('proj', 3, 'todo', title: 'T3'));

      await makeRunner().run(['list', '-p', 'proj', '--offset', '2']);
      final result = parseOutput();
      expect(result.length, equals(1));
      expect(result[0]['id'], equals('proj-003'));
    });

    test('--offset + --limit for pagination', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      for (var i = 1; i <= 10; i++) {
        ticketStore.save(_makeTicket('proj', i, 'todo', title: 'T$i'));
      }

      await makeRunner().run(['list', '-p', 'proj', '--offset', '3', '--limit', '2']);
      final result = parseOutput();
      expect(result.length, equals(2));
      expect(result[0]['id'], equals('proj-004'));
      expect(result[1]['id'], equals('proj-005'));
    });

    test('--sort seq sorts by seq ascending', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 3, 'todo', title: 'T3'));
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'todo', title: 'T2'));

      await makeRunner().run(['list', '-p', 'proj', '--sort', 'seq']);
      final result = parseOutput();
      expect(result[0]['id'], equals('proj-001'));
      expect(result[1]['id'], equals('proj-002'));
      expect(result[2]['id'], equals('proj-003'));
    });

    test('--sort -seq sorts by seq descending', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'todo', title: 'T2'));
      ticketStore.save(_makeTicket('proj', 3, 'todo', title: 'T3'));

      await makeRunner().run(['list', '-p', 'proj', '--sort', '-seq']);
      final result = parseOutput();
      expect(result[0]['id'], equals('proj-003'));
      expect(result[1]['id'], equals('proj-002'));
      expect(result[2]['id'], equals('proj-001'));
    });

    test('--sort created_at sorts by creation time ascending', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1', createdAt: '2026-04-03T10:00:00+09:00'));
      ticketStore.save(_makeTicket('proj', 2, 'todo',
          title: 'T2', createdAt: '2026-04-01T10:00:00+09:00'));
      ticketStore.save(_makeTicket('proj', 3, 'todo',
          title: 'T3', createdAt: '2026-04-02T10:00:00+09:00'));

      await makeRunner().run(['list', '-p', 'proj', '--sort', 'created_at']);
      final result = parseOutput();
      expect(result[0]['id'], equals('proj-002'));
      expect(result[1]['id'], equals('proj-003'));
      expect(result[2]['id'], equals('proj-001'));
    });

    test('--sort + --limit returns sorted then limited', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 3, 'todo', title: 'T3'));
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));
      ticketStore.save(_makeTicket('proj', 2, 'todo', title: 'T2'));

      await makeRunner().run(['list', '-p', 'proj', '--sort', '-seq', '--limit', '2']);
      final result = parseOutput();
      expect(result.length, equals(2));
      expect(result[0]['id'], equals('proj-003'));
      expect(result[1]['id'], equals('proj-002'));
    });

    test('filters by single --where', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj',
          extraFields: '  priority: { type: string }');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1', extraFields: {'priority': 'p0'}));
      ticketStore.save(_makeTicket('proj', 2, 'todo',
          title: 'T2', extraFields: {'priority': 'p1'}));
      ticketStore.save(_makeTicket('proj', 3, 'todo',
          title: 'T3', extraFields: {'priority': 'p0'}));

      await makeRunner().run(['list', '-p', 'proj', '--where', 'priority=p0']);
      final result = parseOutput();
      expect(result.length, equals(2));
      expect(result.every((t) => t['id'] != 'proj-002'), isTrue);
    });

    test('filters by multiple --where with AND logic', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj',
          extraFields: '  priority: { type: string }\n  assignee: { type: string }');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1',
          extraFields: {'priority': 'p0', 'assignee': 'agent-A'}));
      ticketStore.save(_makeTicket('proj', 2, 'todo',
          title: 'T2',
          extraFields: {'priority': 'p0', 'assignee': 'agent-B'}));
      ticketStore.save(_makeTicket('proj', 3, 'todo',
          title: 'T3',
          extraFields: {'priority': 'p1', 'assignee': 'agent-A'}));

      await makeRunner()
          .run(['list', '-p', 'proj', '-w', 'priority=p0', '-w', 'assignee=agent-A']);
      final result = parseOutput();
      expect(result.length, equals(1));
      expect(result[0]['id'], equals('proj-001'));
    });

    test('--where combined with --status', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj',
          extraFields: '  priority: { type: string }');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1', extraFields: {'priority': 'p0'}));
      ticketStore.save(_makeTicket('proj', 2, 'done',
          title: 'T2', extraFields: {'priority': 'p0'}));
      ticketStore.save(_makeTicket('proj', 3, 'todo',
          title: 'T3', extraFields: {'priority': 'p1'}));

      await makeRunner()
          .run(['list', '-p', 'proj', '--status', 'todo', '--where', 'priority=p0']);
      final result = parseOutput();
      expect(result.length, equals(1));
      expect(result[0]['id'], equals('proj-001'));
    });

    test('--where rejects meta fields with hint', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo'));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--where', 'status=todo']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Use --status'))),
      );
    });

    test('default output is id and status only', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'T1'));

      await makeRunner().run(['list', '-p', 'proj']);
      final result = parseOutput();
      expect(result[0].keys.toList(), equals(['id', 'status']));
      expect(result[0]['id'], equals('proj-001'));
      expect(result[0]['status'], equals('todo'));
    });

    test('--fields with custom field', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj',
          extraFields: '  priority: { type: string }');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1', extraFields: {'priority': 'p0'}));

      await makeRunner().run(['list', '-p', 'proj', '--fields', 'id,priority']);
      final result = parseOutput();
      expect(result[0]['priority'], equals('p0'));
    });

    test('--fields rejects unknown field', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo'));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--fields', 'id,nonexistent']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Unknown fields: nonexistent'))),
      );
    });

    test('--fields rejects empty value', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--fields', '']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('at least one field'))),
      );
    });

    test('--where rejects unknown custom field', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj',
          extraFields: '  priority: { type: string }');
      ticketStore.save(_makeTicket('proj', 1, 'todo',
          title: 'T1', extraFields: {'priority': 'p0'}));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--where', 'nonexistent=foo']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Unknown field in --where: nonexistent'))),
      );
    });

    test('--sort rejects unknown field', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo'));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--sort', 'nonexistent']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Unknown sort key: nonexistent'))),
      );
    });

    test('--sort rejects unknown field with descending prefix', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo'));

      expect(
        () => makeRunner().run(['list', '-p', 'proj', '--sort', '-nonexistent']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Unknown sort key: nonexistent'))),
      );
    });

    test('--archived lists archived tickets', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'done', title: 'Archived1'));
      ticketStore.save(_makeTicket('proj', 2, 'todo', title: 'Active'));
      ticketStore.archive('proj', 1);

      await makeRunner().run(['list', '-p', 'proj', '--archived']);
      final result = parseOutput();
      expect(result.length, equals(1));
      expect(result[0]['id'], equals('proj-001'));
    });

    test('--archived returns empty when no archived tickets', () async {
      _writeProjectYaml('${tmpDir.path}/projects', 'proj');
      ticketStore.save(_makeTicket('proj', 1, 'todo', title: 'Active'));

      await makeRunner().run(['list', '-p', 'proj', '--archived']);
      final result = parseOutput();
      expect(result, isEmpty);
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
