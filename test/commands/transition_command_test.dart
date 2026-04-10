import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/transition_command.dart';
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

    out = TestSink();
    runner = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out,
      ));
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('transitions ticket to valid status', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
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
    final out2 = TestSink();
    final runner2 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out2,
      ));

    await runner2.run(['transition', 'game-dev-001', '--to', 'review']);
    loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('review'));

    final out3 = TestSink();
    final runner3 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out3,
      ));

    await runner3.run(['transition', 'game-dev-001', '--to', 'done']);
    loaded = ticketStore.load('game-dev', 1);
    expect(loaded.status, equals('done'));

    // done is terminal
    final out4 = TestSink();
    final runner4 = CommandRunner<void>('ticket', 'test')
      ..addCommand(TransitionCommand(
        projectStore: projectStore,
        ticketStore: ticketStore,
        out: out4,
      ));

    expect(
      () => runner4.run(['transition', 'game-dev-001', '--to', 'backlog']),
      throwsException,
    );
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
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));
      await r.run(['transition', 'tdd-001', '--to', 'green']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('green'));

      final loaded = verifyTicketStore.load('tdd', 1);
      expect(loaded.status, equals('green'));
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

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          basePath: verifyTmpDir.path,
          out: out,
        ));
      await r.run(['transition', 'envcheck-001', '--to', 'done']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('done'));
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

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));

      expect(
        () => r.run(['transition', 'fail-001', '--to', 'done']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Verify failed'))),
      );

      // Ticket should NOT have transitioned
      final loaded = verifyTicketStore.load('fail', 1);
      expect(loaded.status, equals('todo'));
    });

    test('verify script runs with basePath parent as working directory',
        () async {
      // Simulate real layout: projectRoot/scripts/ and projectRoot/.tka/
      final projectRoot =
          Directory.systemTemp.createTempSync('verify_cwd_test_');
      final tkaDir = Directory('${projectRoot.path}/.tka');
      final projectsDir = Directory('${tkaDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${tkaDir.path}/data');
      dataDir.createSync(recursive: true);

      // Script at projectRoot/scripts/check-cwd.sh
      final scriptDir = Directory('${projectRoot.path}/scripts');
      scriptDir.createSync();
      final script = File('${scriptDir.path}/check-cwd.sh');
      script.writeAsStringSync(
          '#!/bin/bash\ntest "\$(pwd -P)" = "\$(cd "${projectRoot.path}" && pwd -P)"');
      Process.runSync('chmod', ['+x', script.path]);

      File('${projectsDir.path}/cwdcheck.yaml').writeAsStringSync('''
version: 1
name: cwdcheck
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo:
      targets: [done]
      verify:
        done: "./scripts/check-cwd.sh"
''');

      final ps = ProjectStore(projectsDir.path);
      final ts = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'cwdcheck',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      ts.save(ticket);

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: ps,
          ticketStore: ts,
          basePath: tkaDir.path,
          out: out,
        ));
      await r.run(['transition', 'cwdcheck-001', '--to', 'done']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('done'));
      projectRoot.deleteSync(recursive: true);
    });

    test('transition succeeds when verify script updates the ticket', () async {
      // Simulate verify script that modifies the ticket (like setup-worktree.sh)
      final projectRoot =
          Directory.systemTemp.createTempSync('verify_update_test_');
      final tkaDir = Directory('${projectRoot.path}/.tka');
      final projectsDir = Directory('${tkaDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${tkaDir.path}/data');
      dataDir.createSync(recursive: true);

      // Script that updates the ticket's field via direct JSON modification
      final scriptDir = Directory('${projectRoot.path}/scripts');
      scriptDir.createSync();
      final script = File('${scriptDir.path}/update-ticket.sh');
      // Modify the ticket JSON file directly to simulate tka update
      script.writeAsStringSync('''#!/bin/bash
TICKET_FILE="${tkaDir.path}/data/updproj/001.json"
# Read, modify updatedAt, and write back
python3 -c "
import json, datetime
with open('\$TICKET_FILE') as f: d = json.load(f)
d['updated_at'] = datetime.datetime.now().isoformat()
d['fields']['worktree'] = '/tmp/test'
with open('\$TICKET_FILE', 'w') as f: json.dump(d, f)
"
''');
      Process.runSync('chmod', ['+x', script.path]);

      File('${projectsDir.path}/updproj.yaml').writeAsStringSync('''
version: 1
name: updproj
description: test
fields:
  title: { type: string, required: true }
  worktree: { type: string }
states:
  initial: todo
  transitions:
    todo:
      targets: [implementing]
      verify:
        implementing: "./scripts/update-ticket.sh"
    implementing: [done]
''');

      final ps = ProjectStore(projectsDir.path);
      final ts = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'updproj',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      ts.save(ticket);

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: ps,
          ticketStore: ts,
          basePath: tkaDir.path,
          out: out,
        ));
      await r.run(['transition', 'updproj-001', '--to', 'implementing']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('implementing'));

      // Verify the ticket has both the verify script's changes and the new status
      final loaded = ts.load('updproj', 1);
      expect(loaded.status, equals('implementing'));
      expect(loaded.fields['worktree'], equals('/tmp/test'));
      projectRoot.deleteSync(recursive: true);
    });

    test('verify output included in success result', () async {
      File('${verifyTmpDir.path}/projects/echo-proj.yaml').writeAsStringSync('''
version: 1
name: echo-proj
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo:
      targets: [done]
      verify:
        done: "echo 'worktree created at /tmp/wt'"
''');

      final ticket = Ticket(
        project: 'echo-proj',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket);

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));
      await r.run(['transition', 'echo-proj-001', '--to', 'done']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('done'));
      expect(json['output'], equals('worktree created at /tmp/wt'));
    });

    test('verify output included in failure error', () async {
      File('${verifyTmpDir.path}/projects/failout.yaml').writeAsStringSync('''
version: 1
name: failout
description: test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo:
      targets: [done]
      verify:
        done: "echo '3 tests failed' && exit 1"
''');

      final ticket = Ticket(
        project: 'failout',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifyTicketStore.save(ticket);

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));

      expect(
        () => r.run(['transition', 'failout-001', '--to', 'done']),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', allOf(
              contains('Verify failed'),
              contains('3 tests failed'),
            ))),
      );
    });

    test('no output field when verify produces no output', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));
      await r.run(['transition', 'tdd-001', '--to', 'green']);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('green'));
      expect(json.containsKey('output'), isFalse);
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

      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifyProjectStore,
          ticketStore: verifyTicketStore,
          out: out,
        ));
      await r.run(['transition', 'tdd-002', '--to', 'red']);
      final loaded = verifyTicketStore.load('tdd', 2);
      expect(loaded.status, equals('red'));
    });
  });

  test('includes guide in result when target state has guide', () async {
    // Replace project with one that has guides
    final projectsDir = Directory('${tmpDir.path}/projects');
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
  guide:
    in_progress: 'Start working on the task'
    review: 'Review the implementation'
''');

    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
    expect(json['guide'], equals('Start working on the task'));
  });

  test('no guide field when target state has no guide', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
    expect(json.containsKey('guide'), isFalse);
  });

  test('updates updatedAt on transition', () async {
    await runner.run(['transition', 'game-dev-001', '--to', 'in_progress']);
    final loaded = ticketStore.load('game-dev', 1);
    final json = loaded.toJson();
    expect(json['updated_at'], isNot(equals('2026-04-01T10:00:00+09:00')));
    expect(json['created_at'], equals('2026-04-01T10:00:00+09:00'));
  });

  group('--set option', () {
    late Directory setTmpDir;
    late ProjectStore setProjectStore;
    late TicketStore setTicketStore;

    setUp(() {
      setTmpDir = Directory.systemTemp.createTempSync('transition_set_test_');
      final projectsDir = Directory('${setTmpDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${setTmpDir.path}/data');
      dataDir.createSync(recursive: true);

      File('${projectsDir.path}/setproj.yaml').writeAsStringSync('''
version: 1
name: setproj
description: test
fields:
  title: { type: string, required: true }
  verdict: { type: string }
  priority: { type: number }
  history: { type: list }
states:
  initial: todo
  transitions:
    todo: [doing]
    doing: [done]
''');

      setProjectStore = ProjectStore(projectsDir.path);
      setTicketStore = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'setproj',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test ticket'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      setTicketStore.save(ticket);
    });

    tearDown(() {
      setTmpDir.deleteSync(recursive: true);
    });

    test('sets field during transition', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: setProjectStore,
          ticketStore: setTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'setproj-001', '--to', 'doing',
        '--set', 'verdict=approved',
      ]);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('doing'));

      final loaded = setTicketStore.load('setproj', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['verdict'], equals('approved'));
    });

    test('sets multiple fields during transition', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: setProjectStore,
          ticketStore: setTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'setproj-001', '--to', 'doing',
        '--set', 'verdict=approved',
        '--set', 'priority=3',
      ]);

      final loaded = setTicketStore.load('setproj', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['verdict'], equals('approved'));
      expect(loaded.fields['priority'], equals(3));
    });

    test('rejects unknown field in --set', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: setProjectStore,
          ticketStore: setTicketStore,
          out: out,
        ));
      expect(
        () => r.run([
          'transition', 'setproj-001', '--to', 'doing',
          '--set', 'nonexistent=value',
        ]),
        throwsA(isA<ArgumentError>()),
      );

      // Ticket should NOT have transitioned
      final loaded = setTicketStore.load('setproj', 1);
      expect(loaded.status, equals('todo'));
    });

    test('rejects --set on list field', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: setProjectStore,
          ticketStore: setTicketStore,
          out: out,
        ));
      expect(
        () => r.run([
          'transition', 'setproj-001', '--to', 'doing',
          '--set', 'history=value',
        ]),
        throwsA(isA<ArgumentError>()),
      );

      final loaded = setTicketStore.load('setproj', 1);
      expect(loaded.status, equals('todo'));
    });
  });

  group('--append option', () {
    late Directory appendTmpDir;
    late ProjectStore appendProjectStore;
    late TicketStore appendTicketStore;

    setUp(() {
      appendTmpDir =
          Directory.systemTemp.createTempSync('transition_append_test_');
      final projectsDir = Directory('${appendTmpDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${appendTmpDir.path}/data');
      dataDir.createSync(recursive: true);

      File('${projectsDir.path}/appproj.yaml').writeAsStringSync('''
version: 1
name: appproj
description: test
fields:
  title: { type: string, required: true }
  history: { type: list }
  tags: { type: list }
  verdict: { type: string }
states:
  initial: todo
  transitions:
    todo: [doing]
    doing: [done]
''');

      appendProjectStore = ProjectStore(projectsDir.path);
      appendTicketStore = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'appproj',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test ticket', 'history': ['created']},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      appendTicketStore.save(ticket);
    });

    tearDown(() {
      appendTmpDir.deleteSync(recursive: true);
    });

    test('appends to list field during transition', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: appendProjectStore,
          ticketStore: appendTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'appproj-001', '--to', 'doing',
        '--append', 'history=started working',
      ]);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('doing'));

      final loaded = appendTicketStore.load('appproj', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['history'], equals(['created', 'started working']));
    });

    test('appends to empty list field', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: appendProjectStore,
          ticketStore: appendTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'appproj-001', '--to', 'doing',
        '--append', 'tags=urgent',
      ]);

      final loaded = appendTicketStore.load('appproj', 1);
      expect(loaded.fields['tags'], equals(['urgent']));
    });

    test('rejects --append on non-list field', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: appendProjectStore,
          ticketStore: appendTicketStore,
          out: out,
        ));
      expect(
        () => r.run([
          'transition', 'appproj-001', '--to', 'doing',
          '--append', 'verdict=approved',
        ]),
        throwsException,
      );

      final loaded = appendTicketStore.load('appproj', 1);
      expect(loaded.status, equals('todo'));
    });

    test('rejects --append on unknown field', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: appendProjectStore,
          ticketStore: appendTicketStore,
          out: out,
        ));
      expect(
        () => r.run([
          'transition', 'appproj-001', '--to', 'doing',
          '--append', 'nonexistent=value',
        ]),
        throwsException,
      );
    });
  });

  group('--set and --append combined', () {
    late Directory comboTmpDir;
    late ProjectStore comboProjectStore;
    late TicketStore comboTicketStore;

    setUp(() {
      comboTmpDir =
          Directory.systemTemp.createTempSync('transition_combo_test_');
      final projectsDir = Directory('${comboTmpDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${comboTmpDir.path}/data');
      dataDir.createSync(recursive: true);

      File('${projectsDir.path}/combo.yaml').writeAsStringSync('''
version: 1
name: combo
description: test
fields:
  title: { type: string, required: true }
  verdict: { type: string }
  history: { type: list }
states:
  initial: todo
  transitions:
    todo: [doing]
    doing: [done]
''');

      comboProjectStore = ProjectStore(projectsDir.path);
      comboTicketStore = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'combo',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test ticket', 'history': ['created']},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      comboTicketStore.save(ticket);
    });

    tearDown(() {
      comboTmpDir.deleteSync(recursive: true);
    });

    test('sets and appends in single transition', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: comboProjectStore,
          ticketStore: comboTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'combo-001', '--to', 'doing',
        '--set', 'verdict=approved',
        '--append', 'history=transitioned to doing',
      ]);
      final json = jsonDecode(out.lines.join('')) as Map<String, dynamic>;
      expect(json['to'], equals('doing'));

      final loaded = comboTicketStore.load('combo', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['verdict'], equals('approved'));
      expect(loaded.fields['history'],
          equals(['created', 'transitioned to doing']));
    });
  });

  group('--set/--append with verify', () {
    late Directory verifySetTmpDir;
    late ProjectStore verifySetProjectStore;
    late TicketStore verifySetTicketStore;

    setUp(() {
      verifySetTmpDir =
          Directory.systemTemp.createTempSync('transition_verify_set_test_');
      final projectsDir = Directory('${verifySetTmpDir.path}/projects');
      projectsDir.createSync(recursive: true);
      final dataDir = Directory('${verifySetTmpDir.path}/data');
      dataDir.createSync(recursive: true);

      File('${projectsDir.path}/vset.yaml').writeAsStringSync('''
version: 1
name: vset
description: test
fields:
  title: { type: string, required: true }
  verdict: { type: string }
  history: { type: list }
states:
  initial: todo
  transitions:
    todo:
      targets: [doing]
      verify:
        doing: "true"
    doing:
      targets: [done]
      verify:
        done: "false"
''');

      verifySetProjectStore = ProjectStore(projectsDir.path);
      verifySetTicketStore = TicketStore(dataDir.path);

      final ticket = Ticket(
        project: 'vset',
        seq: 1,
        status: 'todo',
        fields: {'title': 'Test ticket'},
        createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
        createdAtRaw: '2026-04-01T10:00:00+09:00',
        updatedAtRaw: '2026-04-01T10:00:00+09:00',
      );
      verifySetTicketStore.save(ticket);
    });

    tearDown(() {
      verifySetTmpDir.deleteSync(recursive: true);
    });

    test('applies --set after verify passes', () async {
      final out = TestSink();
      final r = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifySetProjectStore,
          ticketStore: verifySetTicketStore,
          out: out,
        ));
      await r.run([
        'transition', 'vset-001', '--to', 'doing',
        '--set', 'verdict=approved',
      ]);

      final loaded = verifySetTicketStore.load('vset', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['verdict'], equals('approved'));
    });

    test('does not apply --set when verify fails', () async {
      // First transition to doing
      final out1 = TestSink();
      final r1 = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifySetProjectStore,
          ticketStore: verifySetTicketStore,
          out: out1,
        ));
      await r1.run(['transition', 'vset-001', '--to', 'doing']);

      // Try to transition to done (verify fails)
      final out2 = TestSink();
      final r2 = CommandRunner<void>('tka', 'test')
        ..addCommand(TransitionCommand(
          projectStore: verifySetProjectStore,
          ticketStore: verifySetTicketStore,
          out: out2,
        ));
      expect(
        () => r2.run([
          'transition', 'vset-001', '--to', 'done',
          '--set', 'verdict=should-not-persist',
        ]),
        throwsException,
      );

      final loaded = verifySetTicketStore.load('vset', 1);
      expect(loaded.status, equals('doing'));
      expect(loaded.fields['verdict'], isNull);
    });
  });
}
