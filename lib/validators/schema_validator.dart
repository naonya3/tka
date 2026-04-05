import '../models/field_definition.dart';

class SchemaValidator {
  static final _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static List<String> validate(
      Map<String, dynamic> fields, Map<String, FieldDefinition> definitions) {
    final errors = <String>[];
    for (final entry in definitions.entries) {
      final def = entry.value;
      final value = fields[def.name];
      if (value == null || (value is String && value.isEmpty)) {
        if (def.required) {
          errors.add('${def.name}: required field is missing');
        }
        continue;
      }
      final typeError = _validateType(def.name, value, def.type, values: def.values);
      if (typeError != null) errors.add(typeError);
    }
    return errors;
  }

  static String? _validateType(String name, dynamic value, FieldType type, {List<String>? values}) {
    switch (type) {
      case FieldType.string:
        if (value is! String) return '$name: expected string';
      case FieldType.date:
        if (value is! String || !_isValidDate(value)) {
          return '$name: expected date (YYYY-MM-DD)';
        }
      case FieldType.number:
        if (value is! num) return '$name: expected number';
      case FieldType.list:
        if (value is! List) return '$name: expected list';
      case FieldType.enumType:
        if (value is! String || values == null || !values.contains(value)) {
          return '$name: must be one of [${values?.join(', ') ?? ''}]';
        }
    }
    return null;
  }

  static bool _isValidDate(String value) {
    if (!_dateRegex.hasMatch(value)) return false;
    final parts = value.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return false;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }
}
