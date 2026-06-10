import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tka_help_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  ProcessResult runTka(List<String> args) => Process.runSync(
        'dart',
        ['run', 'bin/tka.dart', ...args],
        environment: {'TKA_BASE_PATH': '${tmpDir.path}/.tka-nonexistent'},
      );

  group('help without .tka', () {
    test('--help shows help text and exits 0', () {
      final result = runTka(['--help']);
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Ticket for Agents'));
      expect(result.stderr, contains('Commands:'));
    });

    test('no args shows help text and exits 0', () {
      final result = runTka([]);
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Ticket for Agents'));
      expect(result.stderr, contains('tka init'));
    });

    test('-h shows help text and exits 0', () {
      final result = runTka(['-h']);
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Ticket for Agents'));
    });
  });

  group('errors without .tka are JSON', () {
    test('list with missing TKA_BASE_PATH errors as JSON', () {
      final result = runTka(['list', '-p', 'anything']);
      expect(result.exitCode, 1);
      final err = jsonDecode((result.stderr as String).trim())
          as Map<String, dynamic>;
      expect(err['error'], contains('.tka directory not found'));
      expect(err['error'], contains('tka init'));
    });
  });
}
