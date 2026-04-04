import 'dart:convert';
import 'dart:io';

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
