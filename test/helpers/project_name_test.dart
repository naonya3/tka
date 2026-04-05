import 'package:test/test.dart';
import 'package:tka/helpers/project_name.dart';

void main() {
  group('validateProjectName', () {
    test('accepts simple name', () {
      validateProjectName('myproject');
    });

    test('accepts name with hyphens', () {
      validateProjectName('game-dev');
    });

    test('accepts name with underscores', () {
      validateProjectName('my_project');
    });

    test('accepts name with digits', () {
      validateProjectName('proj2');
    });

    test('accepts single character', () {
      validateProjectName('a');
    });

    test('accepts uppercase letters', () {
      validateProjectName('MyProject');
    });

    test('rejects empty string', () {
      expect(
        () => validateProjectName(''),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('cannot be empty'))),
      );
    });

    test('rejects name starting with hyphen', () {
      expect(
        () => validateProjectName('-project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name starting with underscore', () {
      expect(
        () => validateProjectName('_project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name with spaces', () {
      expect(
        () => validateProjectName('my project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name with dots', () {
      expect(
        () => validateProjectName('my.project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name with slash', () {
      expect(
        () => validateProjectName('my/project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name with backslash', () {
      expect(
        () => validateProjectName('my\\project'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects name with special characters', () {
      expect(
        () => validateProjectName('proj@ct'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
