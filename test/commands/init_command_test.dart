import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/commands/init_command.dart';

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
      final buf = StringBuffer();
      final out = _StringSink(buf);
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

      final output = buf.toString();
      expect(output, contains('"path":'));
      expect(output, isNot(contains('"project"')));
    });

    test('fails if .tka/ already exists', () {
      Directory('${tmpDir.path}/.tka').createSync();
      final buf = StringBuffer();
      final out = _StringSink(buf);
      final cmd = InitCommand(cwd: tmpDir.path, out: out);
      expect(() => cmd.run(), throwsA(isA<InitException>()));
    });
  });
}

class _StringSink implements IOSink {
  final StringBuffer _buf;
  _StringSink(this._buf);

  @override
  void write(Object? obj) => _buf.write(obj);
  @override
  void writeln([Object? obj = '']) => _buf.writeln(obj);
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) => Future.value();
  @override
  Future flush() => Future.value();
  @override
  Future close() => Future.value();
  @override
  Future get done => Future.value();
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
}
