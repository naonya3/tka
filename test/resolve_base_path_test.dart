import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/resolve_base_path.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ticket_resolve_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('resolveBasePath', () {
    test('returns --base value when specified', () {
      final explicit = Directory('${tmpDir.path}/explicit/.tka')
        ..createSync(recursive: true);
      final result = resolveBasePath(
        baseOption: explicit.parent.path + '/.tka',
        cwd: tmpDir.path,
      );
      expect(result, explicit.path);
    });

    test('throws when --base points to non-existing directory', () {
      expect(
        () => resolveBasePath(
          baseOption: '${tmpDir.path}/nope/.tka',
          cwd: tmpDir.path,
        ),
        throwsA(isA<ResolveException>()),
      );
    });

    test('finds .tka in current directory', () {
      Directory('${tmpDir.path}/.tka').createSync();
      final result = resolveBasePath(cwd: tmpDir.path);
      expect(result, '${tmpDir.path}/.tka');
    });

    test('finds .tka in parent directory', () {
      final child = Directory('${tmpDir.path}/sub/deep')
        ..createSync(recursive: true);
      Directory('${tmpDir.path}/.tka').createSync();
      final result = resolveBasePath(cwd: child.path);
      expect(result, '${tmpDir.path}/.tka');
    });

    test('finds .tka in grandparent directory', () {
      final child = Directory('${tmpDir.path}/a/b/c')
        ..createSync(recursive: true);
      Directory('${tmpDir.path}/.tka').createSync();
      final result = resolveBasePath(cwd: child.path);
      expect(result, '${tmpDir.path}/.tka');
    });

    test('throws ResolveNotFound when .tka not found anywhere', () {
      final child = Directory('${tmpDir.path}/empty/sub')
        ..createSync(recursive: true);
      expect(
        () => resolveBasePath(cwd: child.path),
        throwsA(isA<ResolveNotFound>()),
      );
    });
  });
}
