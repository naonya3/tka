import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/project_command.dart';
import 'package:tka/store/project_store.dart';

void main() {
  late Directory tmpDir;
  late String basePath;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ticket_test_');
    basePath = tmpDir.path;
    Directory('$basePath/projects').createSync(recursive: true);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  void writeProject(String name, String content) {
    File('$basePath/projects/$name.yaml').writeAsStringSync(content);
  }

  group('project list', () {
    test('returns empty JSON array when no projects', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'list']);
      expect(output.length, 1);
      final decoded = jsonDecode(output[0]) as List;
      expect(decoded, isEmpty);
    });

    test('lists project names as JSON array', () async {
      writeProject('alpha', _simpleProject('alpha'));
      writeProject('beta', _simpleProject('beta'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'list']);
      expect(output.length, 1);
      final decoded = jsonDecode(output[0]) as List;
      expect(decoded..sort(), ['alpha', 'beta']);
    });
  });

  group('project show', () {
    test('shows project details as JSON', () async {
      writeProject('demo', '''
version: 1
name: demo
description: Demo project
fields:
  title: { type: string, required: true }
  detail: { type: string }
  due: { type: date }
states:
  initial: todo
  transitions:
    todo: [doing]
    doing: [done]
''');
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'show', 'demo']);
      expect(output.length, 1);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['name'], 'demo');
      expect(json['description'], 'Demo project');
      expect(json['fields']['title']['type'], 'string');
      expect(json['fields']['title']['required'], true);
      expect(json['fields']['detail']['type'], 'string');
      expect(json['fields']['detail']['required'], false);
      expect(json['fields']['due']['type'], 'date');
      expect(json['states']['initial'], 'todo');
      expect(json['states']['transitions']['todo'], ['doing']);
      expect(json['states']['transitions']['doing'], ['done']);
    });

    test('shows verify info in transitions JSON', () async {
      writeProject('verify-show', '''
version: 1
name: verify-show
description: Verify show test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo: [implementing]
    implementing:
      targets: [testing]
      verify:
        testing: dart test
    testing: [done]
''');
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'show', 'verify-show']);
      expect(output.length, 1);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      // Simple transitions remain as lists
      expect(json['states']['transitions']['todo'], ['implementing']);
      expect(json['states']['transitions']['testing'], ['done']);
      // Verify transitions become maps
      expect(json['states']['transitions']['implementing'], {
        'targets': ['testing'],
        'verify': {'testing': 'dart test'},
      });
    });

    test('throws when project not found', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
          () => runner.run(['project', 'show', 'nonexistent']),
          throwsA(isA<Exception>()));
    });

    test('throws UsageException when no name given', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
          () => runner.run(['project', 'show']),
          throwsA(isA<UsageException>()));
    });
  });

  group('project templates', () {
    test('returns all 6 templates', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'templates']);
      expect(output.length, 1);
      final decoded = jsonDecode(output[0]) as List;
      expect(decoded.length, 6);
      final names = decoded.map((e) => e['name']).toSet();
      expect(names, {
        'sample', 'tdd', 'review-loop', 'bug-hunt', 'agent-harness', 'evolve'
      });
      for (final item in decoded) {
        expect(item['description'], isNotEmpty);
      }
    });
  });

  group('project add', () {
    test('creates a project with correct name', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'add', 'my-project']);
      expect(output.length, 1);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'my-project');
      expect(json['template'], 'sample');
      final file = File('$basePath/projects/my-project.yaml');
      expect(file.existsSync(), true);
      final content = file.readAsStringSync();
      expect(content.contains('name: my-project'), true);
    });

    test('creates a project with --template tdd', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'add', 'dev-proj', '--template', 'tdd']);
      expect(output.length, 1);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'dev-proj');
      expect(json['template'], 'tdd');
      final content = File('$basePath/projects/dev-proj.yaml').readAsStringSync();
      expect(content.contains('name: dev-proj'), true);
      expect(content.contains('red'), true);
      expect(content.contains('green'), true);
    });

    test('fails if project already exists', () async {
      writeProject('existing', _simpleProject('existing'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
          () => runner.run(['project', 'add', 'existing']),
          throwsA(isA<Exception>()));
    });

    test('fails with invalid template', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
          () => runner.run(['project', 'add', 'foo', '--template', 'nonexistent']),
          throwsA(isA<Exception>()));
    });
  });

  group('project schema', () {
    test('returns schema JSON with field_types', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'schema']);
      expect(output.length, 1);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      final fieldTypes = json['field_types'] as Map<String, dynamic>;
      expect(fieldTypes.keys, containsAll(['string', 'number', 'date', 'list', 'enum']));
      expect(fieldTypes['enum']['required_properties'], contains('values'));
    });

    test('includes verify_cwd in schema output', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'schema']);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['verify_cwd'], equals('Repository root (parent of .tka directory)'));
    });
  });

  group('project add --schema', () {
    test('creates project from JSON schema string', () async {
      final output = <String>[];
      final schema = jsonEncode({
        'description': 'Test project',
        'fields': {
          'title': {'type': 'string', 'required': true},
          'count': {'type': 'number'},
        },
        'states': {
          'initial': 'open',
          'transitions': {
            'open': ['closed'],
          },
        },
      });
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'add', 'from-schema', '--schema', schema]);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'from-schema');
      final file = File('$basePath/projects/from-schema.yaml');
      expect(file.existsSync(), true);
      // Verify the YAML is valid by loading it
      final store = ProjectStore('$basePath/projects');
      final def = store.load('from-schema');
      expect(def.name, 'from-schema');
      expect(def.description, 'Test project');
      expect(def.fields['title']!.required, true);
      expect(def.fields['count']!.type.name, 'number');
      expect(def.stateMachine.initial, 'open');
    });

    test('creates project from stdin with --schema -', () async {
      final output = <String>[];
      final schema = jsonEncode({
        'description': 'Piped',
        'fields': {
          'title': {'type': 'string', 'required': true},
        },
        'states': {
          'initial': 'new',
          'transitions': {
            'new': ['done'],
          },
        },
      });
      final stdinStream = Stream<List<int>>.fromIterable([schema.codeUnits]);
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add, stdinStream: stdinStream));
      await runner.run(['project', 'add', 'piped-proj', '--schema', '-']);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'piped-proj');
      final store = ProjectStore('$basePath/projects');
      final def = store.load('piped-proj');
      expect(def.name, 'piped-proj');
      expect(def.description, 'Piped');
    });

    test('creates project with verify transitions from JSON schema', () async {
      final output = <String>[];
      final schema = jsonEncode({
        'fields': {
          'title': {'type': 'string', 'required': true},
        },
        'states': {
          'initial': 'todo',
          'transitions': {
            'todo': {
              'targets': ['doing'],
              'verify': {'doing': 'echo ok'},
            },
            'doing': ['done'],
          },
        },
      });
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'add', 'verify-proj', '--schema', schema]);
      final store = ProjectStore('$basePath/projects');
      final def = store.load('verify-proj');
      expect(def.stateMachine.initial, 'todo');
      expect(def.stateMachine.getAvailableTransitions('todo'), ['doing']);
      expect(def.stateMachine.getVerify('todo', 'doing'), 'echo ok');
      expect(def.stateMachine.getAvailableTransitions('doing'), ['done']);
    });

    test('rejects invalid JSON', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
        () => runner.run(['project', 'add', 'bad', '--schema', 'not json']),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects schema with invalid field type', () async {
      final output = <String>[];
      final schema = jsonEncode({
        'fields': {
          'title': {'type': 'invalid_type'},
        },
        'states': {
          'initial': 'open',
          'transitions': {'open': ['done']},
        },
      });
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
        () => runner.run(['project', 'add', 'bad-type', '--schema', schema]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('creates project with enum field', () async {
      final output = <String>[];
      final schema = jsonEncode({
        'fields': {
          'title': {'type': 'string', 'required': true},
          'priority': {
            'type': 'enum',
            'values': ['p0', 'p1', 'p2'],
            'description': 'Priority level',
          },
        },
        'states': {
          'initial': 'open',
          'transitions': {'open': ['done']},
        },
      });
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'add', 'enum-proj', '--schema', schema]);
      final store = ProjectStore('$basePath/projects');
      final def = store.load('enum-proj');
      expect(def.fields['priority']!.type.name, 'enumType');
      expect(def.fields['priority']!.values, ['p0', 'p1', 'p2']);
      expect(def.fields['priority']!.description, 'Priority level');
    });
  });

  group('project archive', () {
    test('archives a project', () async {
      writeProject('myproj', _simpleProject('myproj'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'myproj']);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'myproj');
      expect(json['archived'], true);
      expect(File('$basePath/projects/myproj.yaml').existsSync(), false);
      expect(File('$basePath/projects/archived/myproj.yaml').existsSync(), true);
    });

    test('archived project is hidden from list', () async {
      writeProject('alpha', _simpleProject('alpha'));
      writeProject('beta', _simpleProject('beta'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'alpha']);
      output.clear();
      await runner.run(['project', 'list']);
      final list = jsonDecode(output[0]) as List;
      expect(list, ['beta']);
    });

    test('list --archived shows archived projects', () async {
      writeProject('alpha', _simpleProject('alpha'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'alpha']);
      output.clear();
      await runner.run(['project', 'list', '--archived']);
      final list = jsonDecode(output[0]) as List;
      expect(list, ['alpha']);
    });

    test('fails for non-existing project', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
        () => runner.run(['project', 'archive', 'nonexistent']),
        throwsA(isA<Exception>()),
      );
    });

    test('fails when archived project already exists', () async {
      writeProject('reuse', _simpleProject('reuse'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'reuse']);

      // Create a new project with the same name and try to archive again
      writeProject('reuse', _simpleProject('reuse'));
      expect(
        () => runner.run(['project', 'archive', 'reuse']),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('--force'),
        )),
      );
    });

    test('overwrites existing archived project with --force', () async {
      writeProject('reuse', _simpleProject('reuse'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'reuse']);

      // Create a new project with the same name and archive with --force
      writeProject('reuse', _simpleProject('reuse'));
      output.clear();
      await runner.run(['project', 'archive', '--force', 'reuse']);

      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'reuse');
      expect(json['archived'], true);
      expect(File('$basePath/projects/reuse.yaml').existsSync(), false);
      expect(File('$basePath/projects/archived/reuse.yaml').existsSync(), true);
    });
  });

  group('project unarchive', () {
    test('restores an archived project', () async {
      writeProject('myproj', _simpleProject('myproj'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'archive', 'myproj']);
      output.clear();
      await runner.run(['project', 'unarchive', 'myproj']);
      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], 'myproj');
      expect(json['archived'], false);
      expect(File('$basePath/projects/myproj.yaml').existsSync(), true);
      expect(File('$basePath/projects/archived/myproj.yaml').existsSync(), false);
    });

    test('fails for non-archived project', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
        () => runner.run(['project', 'unarchive', 'nonexistent']),
        throwsA(isA<Exception>()),
      );
    });
  });
  group('project workflow', () {
    test('returns workflow with guides, hints, and verify flags', () async {
      writeProject('wf', '''
version: 1
name: wf
description: workflow test
fields:
  title: { type: string, required: true }
states:
  initial: todo
  guide:
    todo: 'Read the ticket and start'
    implementing: 'Write code in worktree'
    done: 'All verified'
  transitions:
    todo:
      targets: [implementing]
      hint:
        implementing: 'Worktree will be created'
      verify:
        implementing: './scripts/setup.sh'
    implementing: [done]
''');
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'workflow', 'wf']);

      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], equals('wf'));
      expect(json['initial'], equals('todo'));

      final states = json['states'] as Map<String, dynamic>;

      // todo state
      final todo = states['todo'] as Map<String, dynamic>;
      expect(todo['guide'], equals('Read the ticket and start'));
      final todoTransitions = todo['transitions'] as List;
      expect(todoTransitions.length, 1);
      final t0 = todoTransitions[0] as Map<String, dynamic>;
      expect(t0['to'], equals('implementing'));
      expect(t0['hint'], equals('Worktree will be created'));
      expect(t0['verify'], isTrue);

      // implementing state
      final impl = states['implementing'] as Map<String, dynamic>;
      expect(impl['guide'], equals('Write code in worktree'));
      final implTransitions = impl['transitions'] as List;
      expect(implTransitions.length, 1);
      expect((implTransitions[0] as Map)['to'], equals('done'));

      // done state (terminal)
      final done = states['done'] as Map<String, dynamic>;
      expect(done['guide'], equals('All verified'));
      expect(done.containsKey('transitions'), isFalse);
    });

    test('works with simple project without guides', () async {
      writeProject('simple', _simpleProject('simple'));
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      await runner.run(['project', 'workflow', 'simple']);

      final json = jsonDecode(output[0]) as Map<String, dynamic>;
      expect(json['project'], equals('simple'));
      expect(json['initial'], equals('todo'));

      final states = json['states'] as Map<String, dynamic>;
      final todo = states['todo'] as Map<String, dynamic>;
      expect(todo.containsKey('guide'), isFalse);
      expect((todo['transitions'] as List).length, 1);
    });

    test('throws when no project name provided', () async {
      final output = <String>[];
      final runner = CommandRunner('tka', 'test')
        ..addCommand(ProjectCommand(basePath, printer: output.add));
      expect(
        () => runner.run(['project', 'workflow']),
        throwsA(isA<UsageException>()),
      );
    });
  });
}

String _simpleProject(String name) => '''
version: 1
name: $name
description: $name project
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo: [done]
''';
