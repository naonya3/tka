import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/create_command.dart';
import 'package:tka/store/project_store.dart';
import 'package:tka/store/ticket_store.dart';
import '../test_helpers.dart';

void main() {
  late Directory tmpDir;
  late String basePath;
  late ProjectStore projectStore;
  late TicketStore ticketStore;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ticket_test_');
    basePath = tmpDir.path;
    Directory('$basePath/projects').createSync(recursive: true);
    Directory('$basePath/data').createSync(recursive: true);
    projectStore = ProjectStore('$basePath/projects');
    ticketStore = TicketStore('$basePath/data');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  void writeProject(String name, String content) {
    File('$basePath/projects/$name.yaml').writeAsStringSync(content);
  }

  group('create', () {
    test('creates a ticket with required fields via --set', () async {
      writeProject('todo', '''
version: 1
name: todo
description: Simple TODO
fields:
  title: { type: string, required: true }
  detail: { type: string }
states:
  initial: open
  transitions:
    open: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      await runner.run(['create', 'todo', '--set', 'title=First task']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['id'], 'todo-001');
      expect(json['seq'], 1);

      final ticket = ticketStore.load('todo', 1);
      expect(ticket.project, 'todo');
      expect(ticket.seq, 1);
      expect(ticket.status, 'open');
      expect(ticket.fields['title'], 'First task');
      expect(ticket.fields['detail'], isNull);
    });

    test('creates sequential tickets', () async {
      writeProject('todo', '''
version: 1
name: todo
description: Simple TODO
fields:
  title: { type: string, required: true }
states:
  initial: open
  transitions:
    open: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      await runner.run(['create', 'todo', '--set', 'title=First']);

      final runner2 = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      await runner2.run(['create', 'todo', '--set', 'title=Second']);

      expect(out.lines.length, 2);
      final json1 = jsonDecode(out.lines[0]) as Map<String, dynamic>;
      final json2 = jsonDecode(out.lines[1]) as Map<String, dynamic>;
      expect(json1['id'], 'todo-001');
      expect(json1['seq'], 1);
      expect(json2['id'], 'todo-002');
      expect(json2['seq'], 2);
    });

    test('fails when required field missing', () async {
      writeProject('todo', '''
version: 1
name: todo
description: Simple TODO
fields:
  title: { type: string, required: true }
states:
  initial: open
  transitions:
    open: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      expect(
          () => runner.run(['create', 'todo']),
          throwsA(isA<UsageException>()));
    });

    test('fails when unknown field specified', () async {
      writeProject('todo', '''
version: 1
name: todo
description: Simple TODO
fields:
  title: { type: string, required: true }
states:
  initial: open
  transitions:
    open: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      expect(
          () => runner.run(['create', 'todo', '--set', 'unknown=value']),
          throwsA(isA<ArgumentError>()));
    });

    test('fails when project not found', () async {
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      expect(
          () => runner.run(['create', 'nonexistent', '--set', 'title=X']),
          throwsA(isA<Exception>()));
    });

    test('throws UsageException when no project name given', () async {
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      expect(
          () => runner.run(['create']),
          throwsA(isA<UsageException>()));
    });

    test('creates ticket with date field via --set', () async {
      writeProject('dated', '''
version: 1
name: dated
description: With date
fields:
  title: { type: string, required: true }
  due: { type: date }
states:
  initial: open
  transitions:
    open: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      await runner.run(
          ['create', 'dated', '--set', 'title=Task', '--set', 'due=2026-04-10']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['id'], 'dated-001');
      expect(json['seq'], 1);

      final ticket = ticketStore.load('dated', 1);
      expect(ticket.fields['due'], '2026-04-10');
    });

    test('initializes list fields as empty list', () async {
      writeProject('dev', '''
version: 1
name: dev
description: Dev project
fields:
  title: { type: string, required: true }
  history: { type: list }
states:
  initial: backlog
  transitions:
    backlog: [done]
''');
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
            projectStore: projectStore, ticketStore: ticketStore, out: out));
      await runner.run(['create', 'dev', '--set', 'title=Feature']);

      final ticket = ticketStore.load('dev', 1);
      expect(ticket.fields['history'], isList);
      expect(ticket.fields['history'], isEmpty);
    });

    test('runs on_create hook after ticket creation', () async {
      writeProject('hooked', '''
version: 1
name: hooked
description: With hook
fields:
  title: { type: string, required: true }
states:
  initial: open
  hooks:
    on_create: "./scripts/on-create.sh"
  transitions:
    open: [done]
''');
      final calls = <_ProcessCall>[];
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
          projectStore: projectStore,
          ticketStore: ticketStore,
          out: out,
          basePath: basePath,
          processStarter: (String command, List<String> args,
              {Map<String, String>? environment,
              ProcessStartMode? mode}) async {
            calls.add(_ProcessCall(command, args, environment ?? {}, mode));
            return _FakeProcess();
          },
        ));
      await runner.run(['create', 'hooked', '--set', 'title=Test']);

      expect(calls, hasLength(1));
      final call = calls.first;
      expect(call.command, equals('./scripts/on-create.sh'));
      expect(call.environment['TKA_TICKET_ID'], equals('hooked-001'));
      expect(call.environment['TKA_TICKET_PROJECT'], equals('hooked'));
      expect(call.environment['TKA_TICKET_SEQ'], equals('1'));
      expect(call.environment['TKA_TICKET_STATUS'], equals('open'));
      expect(call.environment['TKA_BASE_PATH'], equals(basePath));
      expect(call.mode, equals(ProcessStartMode.detached));
    });

    test('does not call processStarter when no on_create hook', () async {
      writeProject('nohook', '''
version: 1
name: nohook
description: No hook
fields:
  title: { type: string, required: true }
states:
  initial: open
  transitions:
    open: [done]
''');
      final calls = <_ProcessCall>[];
      final out = TestSink();
      final runner = CommandRunner('tka', 'test')
        ..addCommand(CreateCommand(
          projectStore: projectStore,
          ticketStore: ticketStore,
          out: out,
          basePath: basePath,
          processStarter: (String command, List<String> args,
              {Map<String, String>? environment,
              ProcessStartMode? mode}) async {
            calls.add(_ProcessCall(command, args, environment ?? {}, mode));
            return _FakeProcess();
          },
        ));
      await runner.run(['create', 'nohook', '--set', 'title=Test']);

      expect(calls, isEmpty);
    });
  });
}

class _ProcessCall {
  final String command;
  final List<String> args;
  final Map<String, String> environment;
  final ProcessStartMode? mode;
  _ProcessCall(this.command, this.args, this.environment, this.mode);
}

class _FakeProcess implements Process {
  @override
  Future<int> get exitCode => Future.value(0);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
  @override
  int get pid => 0;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  IOSink get stdin => _NullIOSink();
  @override
  Stream<List<int>> get stdout => const Stream.empty();
}

class _NullIOSink implements IOSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
