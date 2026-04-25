import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/commands/init_command.dart';
import '../test_helpers.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ticket_init_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('init', () {
    test('creates .tka/projects/ and .tka/data/ without sample project', () async {
      final out = TestSink();
      final cmd = InitCommand(cwd: tmpDir.path, out: out);
      cmd.run();

      expect(Directory('${tmpDir.path}/.tka/projects').existsSync(), isTrue);
      expect(Directory('${tmpDir.path}/.tka/data').existsSync(), isTrue);

      final projectFiles = Directory('${tmpDir.path}/.tka/projects')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList();
      expect(projectFiles, isEmpty);

      final output = out.toString();
      expect(output, contains('"path":'));
      expect(output, isNot(contains('"project"')));
    });

    test('fails if .tka/ already exists', () {
      Directory('${tmpDir.path}/.tka').createSync();
      final out = TestSink();
      final cmd = InitCommand(cwd: tmpDir.path, out: out);
      expect(() => cmd.run(), throwsA(isA<InitException>()));
    });

    test('CLI emits JSON error on second init', () {
      Directory('${tmpDir.path}/.tka').createSync();
      final repoRoot = Directory.current.path;
      final result = Process.runSync(
        'dart',
        ['run', '$repoRoot/bin/tka.dart', 'init'],
        workingDirectory: tmpDir.path,
      );
      expect(result.exitCode, 1);
      // stderr should be valid JSON with an "error" key, not plaintext.
      final firstLine = (result.stderr as String).trim().split('\n').last;
      final parsed = jsonDecode(firstLine) as Map<String, dynamic>;
      expect(parsed['error'], contains('.tka already exists'));
    });
  });
}
