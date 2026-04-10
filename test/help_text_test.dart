import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('help text', () {
    late ProcessResult result;

    setUpAll(() {
      result = Process.runSync('dart', ['run', 'bin/tka.dart', '-h']);
    });

    test('shows --base in Global options section', () {
      final output = result.stdout as String;
      // --base should appear in Global options, between the header and the Available commands
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
  });
}
