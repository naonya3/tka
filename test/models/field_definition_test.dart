import 'package:test/test.dart';
import 'package:tka/models/field_definition.dart';

void main() {
  group('FieldDefinition.fromYaml', () {
    test('parses type string with required true', () {
      final fd = FieldDefinition.fromYaml('title', {'type': 'string', 'required': true});
      expect(fd.name, equals('title'));
      expect(fd.type, equals(FieldType.string));
      expect(fd.required, isTrue);
    });

    test('required defaults to false', () {
      final fd = FieldDefinition.fromYaml('detail', {'type': 'string'});
      expect(fd.name, equals('detail'));
      expect(fd.type, equals(FieldType.string));
      expect(fd.required, isFalse);
    });

    test('parses all 4 field types', () {
      final cases = {
        'string': FieldType.string,
        'date': FieldType.date,
        'list': FieldType.list,
        'number': FieldType.number,
      };
      for (final entry in cases.entries) {
        final fd = FieldDefinition.fromYaml('f', {'type': entry.key});
        expect(fd.type, equals(entry.value), reason: 'type ${entry.key}');
      }
    });

    test('unknown field type throws', () {
      expect(
        () => FieldDefinition.fromYaml('f', {'type': 'boolean'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parses enum type', () {
      final fd = FieldDefinition.fromYaml('priority', {
        'type': 'enum',
        'values': ['p0', 'p1', 'p2'],
      });
      expect(fd.type, equals(FieldType.enumType));
      expect(fd.values, equals(['p0', 'p1', 'p2']));
    });

    test('parses description', () {
      final fd = FieldDefinition.fromYaml('detail', {
        'type': 'string',
        'description': 'A detailed description',
      });
      expect(fd.description, equals('A detailed description'));
    });

    test('description defaults to null', () {
      final fd = FieldDefinition.fromYaml('title', {'type': 'string'});
      expect(fd.description, isNull);
    });

    test('values defaults to null for non-enum types', () {
      final fd = FieldDefinition.fromYaml('title', {'type': 'string'});
      expect(fd.values, isNull);
    });

    test('enum type without values throws', () {
      expect(
        () => FieldDefinition.fromYaml('priority', {'type': 'enum'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('unknown property throws', () {
      expect(
        () => FieldDefinition.fromYaml('f', {'type': 'string', 'enum': ['a', 'b']}),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains("Unknown properties 'enum'"))),
      );
    });

    test('values on non-enum type throws', () {
      expect(
        () => FieldDefinition.fromYaml('f', {'type': 'string', 'values': ['a', 'b']}),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', contains("Did you mean type: 'enum'"))),
      );
    });
  });
}
