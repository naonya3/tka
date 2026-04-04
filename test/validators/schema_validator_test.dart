import 'package:test/test.dart';
import 'package:tka/models/field_definition.dart';
import 'package:tka/validators/schema_validator.dart';

void main() {
  group('SchemaValidator', () {
    test('valid string field passes', () {
      final defs = {
        'title': FieldDefinition(name: 'title', type: FieldType.string, required: false),
      };
      final errors = SchemaValidator.validate({'title': 'hello'}, defs);
      expect(errors, isEmpty);
    });

    test('valid date field (YYYY-MM-DD) passes', () {
      final defs = {
        'due': FieldDefinition(name: 'due', type: FieldType.date, required: false),
      };
      final errors = SchemaValidator.validate({'due': '2026-04-01'}, defs);
      expect(errors, isEmpty);
    });

    test('invalid date format fails (MM-DD-YYYY)', () {
      final defs = {
        'due': FieldDefinition(name: 'due', type: FieldType.date, required: false),
      };
      final errors = SchemaValidator.validate({'due': '04-01-2026'}, defs);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('due'));
    });

    test('invalid date format fails (not-a-date)', () {
      final defs = {
        'due': FieldDefinition(name: 'due', type: FieldType.date, required: false),
      };
      final errors = SchemaValidator.validate({'due': 'not-a-date'}, defs);
      expect(errors, isNotEmpty);
    });

    test('valid number field passes (int)', () {
      final defs = {
        'priority': FieldDefinition(name: 'priority', type: FieldType.number, required: false),
      };
      final errors = SchemaValidator.validate({'priority': 1}, defs);
      expect(errors, isEmpty);
    });

    test('valid number field passes (double)', () {
      final defs = {
        'score': FieldDefinition(name: 'score', type: FieldType.number, required: false),
      };
      final errors = SchemaValidator.validate({'score': 3.14}, defs);
      expect(errors, isEmpty);
    });

    test('invalid number field fails', () {
      final defs = {
        'priority': FieldDefinition(name: 'priority', type: FieldType.number, required: false),
      };
      final errors = SchemaValidator.validate({'priority': 'abc'}, defs);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('priority'));
    });

    test('valid list field passes', () {
      final defs = {
        'history': FieldDefinition(name: 'history', type: FieldType.list, required: false),
      };
      final errors = SchemaValidator.validate({'history': ['a', 'b']}, defs);
      expect(errors, isEmpty);
    });

    test('required field missing (null) fails', () {
      final defs = {
        'title': FieldDefinition(name: 'title', type: FieldType.string, required: true),
      };
      final errors = SchemaValidator.validate({'title': null}, defs);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('title'));
    });

    test('required field missing (absent) fails', () {
      final defs = {
        'title': FieldDefinition(name: 'title', type: FieldType.string, required: true),
      };
      final errors = SchemaValidator.validate({}, defs);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('title'));
    });

    test('required field present passes', () {
      final defs = {
        'title': FieldDefinition(name: 'title', type: FieldType.string, required: true),
      };
      final errors = SchemaValidator.validate({'title': 'hello'}, defs);
      expect(errors, isEmpty);
    });

    test('optional field can be null', () {
      final defs = {
        'detail': FieldDefinition(name: 'detail', type: FieldType.string, required: false),
      };
      final errors = SchemaValidator.validate({'detail': null}, defs);
      expect(errors, isEmpty);
    });

    test('optional field can be absent', () {
      final defs = {
        'detail': FieldDefinition(name: 'detail', type: FieldType.string, required: false),
      };
      final errors = SchemaValidator.validate({}, defs);
      expect(errors, isEmpty);
    });

    test('unknown field in fields is ignored', () {
      final defs = {
        'title': FieldDefinition(name: 'title', type: FieldType.string, required: false),
      };
      final errors = SchemaValidator.validate({'title': 'hi', 'extra': 'stuff'}, defs);
      expect(errors, isEmpty);
    });

    test('valid enum value passes', () {
      final defs = {
        'priority': FieldDefinition(
          name: 'priority',
          type: FieldType.enumType,
          required: false,
          values: ['p0', 'p1', 'p2'],
        ),
      };
      final errors = SchemaValidator.validate({'priority': 'p1'}, defs);
      expect(errors, isEmpty);
    });

    test('invalid enum value fails with allowed values listed', () {
      final defs = {
        'priority': FieldDefinition(
          name: 'priority',
          type: FieldType.enumType,
          required: false,
          values: ['p0', 'p1', 'p2'],
        ),
      };
      final errors = SchemaValidator.validate({'priority': 'p9'}, defs);
      expect(errors, hasLength(1));
      expect(errors.first, contains('priority'));
      expect(errors.first, contains('must be one of'));
      expect(errors.first, contains('p0'));
      expect(errors.first, contains('p1'));
      expect(errors.first, contains('p2'));
    });
  });
}
