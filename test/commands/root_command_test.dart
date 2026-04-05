import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:tka/commands/root_command.dart';

void main() {
  group('root command', () {
    test('outputs basePath', () async {
      final out = _TestSink();
      final runner = CommandRunner<void>('ticket', 'test');
      runner.addCommand(RootCommand(basePath: '/home/user/.tka', out: out));

      await runner.run(['root']);
      expect(out.lines, equals(['/home/user/.tka']));
    });

    test('outputs absolute path as-is', () async {
      final out = _TestSink();
      final runner = CommandRunner<void>('ticket', 'test');
      runner.addCommand(RootCommand(basePath: '/tmp/test-project/.tka', out: out));

      await runner.run(['root']);
      expect(out.lines.first, equals('/tmp/test-project/.tka'));
    });
  });
}

class _TestSink implements IOSink {
  final List<String> lines = [];

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  void write(Object? object) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
