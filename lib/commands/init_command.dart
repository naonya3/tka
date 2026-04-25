import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';

class InitException implements Exception {
  final String message;
  InitException(this.message);
  @override
  String toString() => message;
}

class InitCommand {
  final String _cwd;
  final IOSink _out;

  InitCommand({String? cwd, IOSink? out})
      : _cwd = cwd ?? Directory.current.path,
        _out = out ?? stdout;

  void run() {
    final ticketDir = Directory('$_cwd/.tka');
    if (ticketDir.existsSync()) {
      throw InitException('.tka already exists in $_cwd');
    }
    Directory('$_cwd/.tka/projects').createSync(recursive: true);
    Directory('$_cwd/.tka/data').createSync(recursive: true);
    _out.writeln(jsonEncode({
      'path': ticketDir.absolute.path,
    }));
  }

  static const usage =
      'tka init    Initialize .tka/ in current directory';
}

/// Stub Command that exists only so `init` appears in `tka -h`'s
/// "Available commands:" listing. Actual execution is special-cased in
/// bin/tka.dart before the runner is invoked, because init must run
/// without a resolved .tka base path.
class InitStubCommand extends Command<void> {
  @override
  final String name = 'init';
  @override
  final String description = 'Initialize .tka/ in the current directory.';

  @override
  void run() {
    // Unreachable in normal flow — bin/tka.dart intercepts `init` before
    // delegating to CommandRunner. Kept as a defensive no-op fallback.
    throw UnimplementedError(
        'init is intercepted by the entry-point; this stub should not run.');
  }
}
