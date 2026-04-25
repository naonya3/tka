import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/migrate_command.dart';
import '../test_helpers.dart';

void main() {
  late Directory tmpDir;
  late String basePath;
  late TestSink out;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('migrate_cmd_test_');
    basePath = tmpDir.path;
    Directory('$basePath/projects').createSync(recursive: true);
    Directory('$basePath/data').createSync(recursive: true);
    out = TestSink();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  CommandRunner<void> makeRunner() {
    final runner = CommandRunner<void>('tka', 'test');
    runner.addCommand(MigrateCommand(basePath: basePath, out: out));
    return runner;
  }

  Map<String, dynamic> runMigrate(List<String> extraArgs) {
    final args = ['migrate', ...extraArgs];
    makeRunner().run(args);
    return jsonDecode(out.lines.join('')) as Map<String, dynamic>;
  }

  test('moves title from fields to top-level on tickets', () async {
    Directory('$basePath/data/proj').createSync();
    File('$basePath/data/proj/001.json').writeAsStringSync(jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'status': 'todo',
      'fields': {'title': 'Buy milk', 'detail': 'whole'},
      'created_at': '2026-04-01T10:00:00',
      'updated_at': '2026-04-01T10:00:00',
    }));

    final report = runMigrate([]);
    expect(report['tickets_migrated'], 1);
    expect(report['errors'], isEmpty);

    final after =
        jsonDecode(File('$basePath/data/proj/001.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(after['title'], 'Buy milk');
    expect((after['fields'] as Map).containsKey('title'), isFalse);
    expect((after['fields'] as Map)['detail'], 'whole');
  });

  test('removes title from project schema fields', () async {
    File('$basePath/projects/proj.yaml').writeAsStringSync('''
version: 1
name: proj
fields:
  title: { type: string, required: true }
  detail: { type: string }
states:
  initial: todo
  transitions:
    todo: [done]
''');

    final report = runMigrate([]);
    expect(report['projects_migrated'], 1);
    expect(report['errors'], isEmpty);

    final after = File('$basePath/projects/proj.yaml').readAsStringSync();
    expect(after.contains('title:'), isFalse);
    expect(after.contains('detail:'), isTrue);
    expect(after.contains('version: 2'), isTrue);
  });

  test('handles block-form title declaration', () async {
    File('$basePath/projects/proj.yaml').writeAsStringSync('''
version: 1
name: proj
fields:
  title:
    type: string
    required: true
  detail: { type: string }
states:
  initial: todo
  transitions:
    todo: [done]
''');

    runMigrate([]);

    final after = File('$basePath/projects/proj.yaml').readAsStringSync();
    expect(after.contains('title'), isFalse);
    expect(after.contains('detail'), isTrue);
  });

  test('is idempotent — already-migrated data is skipped', () async {
    Directory('$basePath/data/proj').createSync();
    File('$basePath/data/proj/001.json').writeAsStringSync(jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'title': 'Already migrated',
      'status': 'todo',
      'fields': {'detail': 'x'},
      'created_at': '2026-04-01T10:00:00',
      'updated_at': '2026-04-01T10:00:00',
    }));
    File('$basePath/projects/proj.yaml').writeAsStringSync('''
version: 2
name: proj
fields:
  detail: { type: string }
states:
  initial: todo
  transitions:
    todo: [done]
''');

    final report = runMigrate([]);
    expect(report['tickets_migrated'], 0);
    expect(report['tickets_skipped'], 1);
    expect(report['projects_migrated'], 0);
    expect(report['projects_skipped'], 1);
  });

  test('--dry-run does not modify files', () async {
    Directory('$basePath/data/proj').createSync();
    final original = jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'status': 'todo',
      'fields': {'title': 'Buy milk'},
      'created_at': '2026-04-01T10:00:00',
      'updated_at': '2026-04-01T10:00:00',
    });
    File('$basePath/data/proj/001.json').writeAsStringSync(original);

    final report = runMigrate(['--dry-run']);
    expect(report['dry_run'], isTrue);
    expect(report['tickets_migrated'], 1);

    expect(File('$basePath/data/proj/001.json').readAsStringSync(), original);
  });

  test('reports error for ticket with no title anywhere', () async {
    Directory('$basePath/data/proj').createSync();
    File('$basePath/data/proj/001.json').writeAsStringSync(jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'status': 'todo',
      'fields': {'detail': 'no title'},
      'created_at': '2026-04-01T10:00:00',
      'updated_at': '2026-04-01T10:00:00',
    }));

    final report = runMigrate([]);
    expect(report['tickets_migrated'], 0);
    expect((report['errors'] as List).length, 1);
  });

  test('migrates archived projects too', () async {
    Directory('$basePath/projects/archived').createSync(recursive: true);
    File('$basePath/projects/archived/old.yaml').writeAsStringSync('''
version: 1
name: old
fields:
  title: { type: string, required: true }
states:
  initial: todo
  transitions:
    todo: [done]
''');

    final report = runMigrate([]);
    expect(report['projects_migrated'], 1);
  });

  test('migrates archived tickets too', () async {
    Directory('$basePath/data/proj/archived').createSync(recursive: true);
    File('$basePath/data/proj/archived/001.json').writeAsStringSync(jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'status': 'done',
      'fields': {'title': 'Old task'},
      'created_at': '2026-04-01T10:00:00',
      'updated_at': '2026-04-01T10:00:00',
    }));

    final report = runMigrate([]);
    expect(report['tickets_migrated'], 1);

    final after = jsonDecode(
            File('$basePath/data/proj/archived/001.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(after['title'], 'Old task');
  });
}
