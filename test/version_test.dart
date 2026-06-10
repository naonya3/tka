import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/version.dart';

void main() {
  test('tkaVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(tkaVersion, equals(match));
  });

  test('--version outputs version JSON and exits 0', () {
    final result = Process.runSync('dart', ['run', 'bin/tka.dart', '--version']);
    expect(result.exitCode, 0);
    final out = jsonDecode((result.stdout as String).trim())
        as Map<String, dynamic>;
    expect(out['version'], equals(tkaVersion));
  });
}
