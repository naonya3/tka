import 'dart:io';
import 'package:test/test.dart';
import 'package:tka/helpers/field_input.dart';
import 'package:tka/models/field_definition.dart';

void main() {
  group('resolveFieldValue', () {
    test('returns null for null input', () {
      expect(resolveFieldValue(null), isNull);
    });

    test('returns plain string as-is', () {
      expect(resolveFieldValue('hello'), equals('hello'));
    });

    test('returns empty string as-is', () {
      expect(resolveFieldValue(''), equals(''));
    });

    test('reads file content for @path', () {
      final tmpFile = File('${Directory.systemTemp.path}/field_input_test.txt');
      tmpFile.writeAsStringSync('file content here');
      addTearDown(() => tmpFile.deleteSync());

      expect(
        resolveFieldValue('@${tmpFile.path}'),
        equals('file content here'),
      );
    });

    test('reads multiline file content for @path', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/field_input_test_multi.txt');
      tmpFile.writeAsStringSync('line1\nline2\nline3');
      addTearDown(() => tmpFile.deleteSync());

      expect(
        resolveFieldValue('@${tmpFile.path}'),
        equals('line1\nline2\nline3'),
      );
    });

    test('throws for @path when file does not exist', () {
      expect(
        () => resolveFieldValue('@/nonexistent/path/file.txt'),
        throwsA(isA<Exception>()),
      );
    });

    test('escapes @@ to literal @', () {
      expect(resolveFieldValue('@@twitter'), equals('@twitter'));
    });

    test('does not treat @@ as file path', () {
      expect(resolveFieldValue('@@/some/path'), equals('@/some/path'));
    });

    test('@@ only escapes at start, not in middle', () {
      expect(resolveFieldValue('aaa@@bbb'), equals('aaa@@bbb'));
    });

    test('@@@@ at start removes one leading @', () {
      expect(resolveFieldValue('@@@@four'), equals('@@@four'));
    });

    test('plain text with @ in middle is unchanged', () {
      expect(resolveFieldValue('user@example.com'), equals('user@example.com'));
    });
  });

  group('parseSetOption', () {
    test('parses basic field=value', () {
      final (field, value) = parseSetOption('title=hello');
      expect(field, equals('title'));
      expect(value, equals('hello'));
    });

    test('splits on first = only, value can contain =', () {
      final (field, value) = parseSetOption('detail=x=y=z');
      expect(field, equals('detail'));
      expect(value, equals('x=y=z'));
    });

    test('throws FormatException when no = present', () {
      expect(() => parseSetOption('noequals'), throwsA(isA<FormatException>()));
    });
  });

  group('coerceValue', () {
    test('returns string as-is for string type', () {
      final def = FieldDefinition(name: 'title', type: FieldType.string, required: true);
      expect(coerceValue('hello', def), equals('hello'));
    });

    test('converts valid number string to num', () {
      final def = FieldDefinition(name: 'qty', type: FieldType.number, required: false);
      expect(coerceValue('42', def), equals(42));
    });

    test('converts decimal number string to num', () {
      final def = FieldDefinition(name: 'qty', type: FieldType.number, required: false);
      expect(coerceValue('3.14', def), equals(3.14));
    });

    test('throws FormatException for invalid number', () {
      final def = FieldDefinition(name: 'qty', type: FieldType.number, required: false);
      expect(() => coerceValue('abc', def), throwsA(isA<FormatException>()));
    });

    test('returns date string as-is for date type', () {
      final def = FieldDefinition(name: 'due', type: FieldType.date, required: false);
      expect(coerceValue('2026-04-05', def), equals('2026-04-05'));
    });

    test('wraps value in list for list type', () {
      final def = FieldDefinition(name: 'history', type: FieldType.list, required: false);
      expect(coerceValue('entry1', def), equals(['entry1']));
    });

    test('returns string as-is for enum type', () {
      final def = FieldDefinition(name: 'priority', type: FieldType.enumType, required: false, values: ['p0', 'p1']);
      expect(coerceValue('p0', def), equals('p0'));
    });

    test('returns empty string for empty number input (clear)', () {
      final def = FieldDefinition(name: 'qty', type: FieldType.number, required: false);
      expect(coerceValue('', def), equals(''));
    });
  });

  group('buildFieldsFromSetOptions', () {
    final fieldDefs = {
      'title': FieldDefinition(name: 'title', type: FieldType.string, required: true),
      'quantity': FieldDefinition(name: 'quantity', type: FieldType.number, required: false),
      'due': FieldDefinition(name: 'due', type: FieldType.date, required: false),
      'history': FieldDefinition(name: 'history', type: FieldType.list, required: false),
    };

    test('builds map from multiple --set options', () {
      final result = buildFieldsFromSetOptions(
        ['title=Buy milk', 'quantity=3'],
        fieldDefs,
      );
      expect(result, equals({'title': 'Buy milk', 'quantity': 3}));
    });

    test('throws ArgumentError for unknown field', () {
      expect(
        () => buildFieldsFromSetOptions(['unknown=val'], fieldDefs),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('applies resolveFieldValue to string fields with @file', () {
      final tmpFile = File('${Directory.systemTemp.path}/build_fields_test.txt');
      tmpFile.writeAsStringSync('file content');
      addTearDown(() => tmpFile.deleteSync());

      final result = buildFieldsFromSetOptions(
        ['title=@${tmpFile.path}'],
        fieldDefs,
      );
      expect(result['title'], equals('file content'));
    });

    test('applies resolveFieldValue to date fields', () {
      final result = buildFieldsFromSetOptions(
        ['due=2026-04-05'],
        fieldDefs,
      );
      expect(result['due'], equals('2026-04-05'));
    });

    test('does not apply resolveFieldValue to number fields', () {
      final result = buildFieldsFromSetOptions(
        ['quantity=5'],
        fieldDefs,
      );
      expect(result['quantity'], equals(5));
    });
  });
}
