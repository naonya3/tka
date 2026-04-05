import 'dart:io';

/// Test IOSink that captures output as a list of strings.
///
/// Usage:
///   final out = TestSink();
///   // pass out to command constructor
///   final result = jsonDecode(out.lines.join(''));
class TestSink implements IOSink {
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

  @override
  String toString() => lines.join('\n');
}
