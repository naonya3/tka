import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('help text (with .tka)', () {
    late ProcessResult result;

    setUpAll(() {
      result = Process.runSync('dart', ['run', 'bin/tka.dart', '-h']);
    });

    test('shows --base in Global options section', () {
      final output = result.stdout as String;
      expect(output, contains('--base'));
      expect(output, contains('Path to .tka directory'));
    });

    test('shows --base usage example in Examples section', () {
      final output = result.stdout as String;
      expect(output, contains('tka --base /path/to/.tka'));
    });

    test('--base appears before Available commands section', () {
      final output = result.stdout as String;
      final baseIndex = output.indexOf('--base');
      final commandsIndex = output.indexOf('Available commands:');
      expect(baseIndex, greaterThan(-1),
          reason: '--base should be present in help text');
      expect(commandsIndex, greaterThan(-1),
          reason: 'Available commands should be present');
      expect(baseIndex, lessThan(commandsIndex),
          reason: '--base should appear before Available commands');
    });

    test('init appears in Available commands listing', () {
      final output = result.stdout as String;
      expect(output, matches(RegExp(r'^\s+init\s+Initialize \.tka/', multiLine: true)),
          reason: 'init should appear in the Available commands block, not only in Examples');
    });
  });

  group('fallback help text (without .tka)', () {
    late Directory tmpDir;
    late ProcessResult result;

    setUpAll(() {
      // Create a temp directory with no .tka to trigger fallback help
      tmpDir = Directory.systemTemp.createTempSync('tka_help_test_');
      // Run tka with no args from a directory without .tka
      // Use environment to unset TKA_BASE_PATH
      result = Process.runSync(
        'dart',
        ['run', 'bin/tka.dart'],
        environment: {'TKA_BASE_PATH': '${tmpDir.path}/nonexistent'},
      );
    });

    tearDownAll(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('shows --base in fallback help', () {
      final output = result.stderr as String;
      expect(output, contains('--base'));
      expect(output, contains('Path to .tka directory'));
    });

    test('shows --base usage example in fallback help', () {
      final output = result.stderr as String;
      expect(output, contains('tka --base /path/to/.tka'));
    });
  });
}
