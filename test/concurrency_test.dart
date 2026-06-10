import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

const _projectYaml = '''
version: 2
name: proj
fields:
  detail: { type: string }
states:
  initial: todo
  transitions:
    todo: [done]
''';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tka_concurrency_test_');
    Directory('${tmpDir.path}/projects').createSync(recursive: true);
    Directory('${tmpDir.path}/data/proj').createSync(recursive: true);
    File('${tmpDir.path}/projects/proj.yaml').writeAsStringSync(_projectYaml);
    File('${tmpDir.path}/data/proj/001.json').writeAsStringSync(jsonEncode({
      'id': 'proj-001',
      'project': 'proj',
      'seq': 1,
      'title': 'race target',
      'status': 'todo',
      'fields': {'detail': null},
      'created_at': '2026-06-11T00:00:00',
      'updated_at': '2026-06-11T00:00:00',
    }));
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('losing a concurrent update returns a retryable JSON error', () async {
    // Not every round actually races; run several so losers can appear.
    for (var round = 0; round < 5; round++) {
      final results = await Future.wait([
        Process.run('dart', [
          'run',
          'bin/tka.dart',
          '--base',
          tmpDir.path,
          'update',
          'proj-001',
          '--set',
          'detail=from-A-$round',
        ]),
        Process.run('dart', [
          'run',
          'bin/tka.dart',
          '--base',
          tmpDir.path,
          'update',
          'proj-001',
          '--set',
          'detail=from-B-$round',
        ]),
      ]);
      for (final r in results) {
        if (r.exitCode == 0) continue;
        final err =
            jsonDecode((r.stderr as String).trim()) as Map<String, dynamic>;
        expect(err['error'], contains('modified concurrently'),
            reason: 'loser must get a retryable error, got: ${err['error']}');
        expect(err['error'], contains('retry'));
      }
    }
  }, timeout: Timeout(Duration(minutes: 2)));
}
