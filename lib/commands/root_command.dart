import 'dart:io';
import 'package:args/command_runner.dart';

class RootCommand extends Command<void> {
  @override
  final String name = 'root';
  @override
  final String description = '''Print the resolved .tka directory path.

Usage: tka root
Output: absolute path string (not JSON).''';

  final String basePath;
  final IOSink _out;

  RootCommand({required this.basePath, IOSink? out}) : _out = out ?? stdout;

  @override
  void run() {
    _out.writeln(basePath);
  }
}
