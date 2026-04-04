enum FieldType { string, date, list, number, enumType }

FieldType parseFieldType(String s) {
  if (s == 'enum') return FieldType.enumType;
  for (final t in FieldType.values) {
    if (t.name == s) return t;
  }
  throw ArgumentError('Unknown field type: $s');
}

class FieldDefinition {
  final String name;
  final FieldType type;
  final bool required;
  final String? description;
  final List<String>? values;

  FieldDefinition({
    required this.name,
    required this.type,
    required this.required,
    this.description,
    this.values,
  });

  static const _knownProperties = {'type', 'required', 'description', 'values'};

  factory FieldDefinition.fromYaml(String name, Map data) {
    final unknown = data.keys.cast<String>().where((k) => !_knownProperties.contains(k)).toList();
    if (unknown.isNotEmpty) {
      throw ArgumentError(
          "Unknown properties ${unknown.map((k) => "'$k'").join(', ')} in field '$name'. "
          "Valid properties: ${_knownProperties.join(', ')}");
    }

    final type = parseFieldType(data['type'] as String);
    final values = (data['values'] as List?)?.cast<String>();
    if (type == FieldType.enumType && (values == null || values.isEmpty)) {
      throw ArgumentError('enum type requires non-empty "values" list for field: $name');
    }
    if (type != FieldType.enumType && values != null) {
      throw ArgumentError(
          "'values' is only valid for enum type, but field '$name' has type '${type.name}'. "
          "Did you mean type: 'enum' with 'values'?");
    }
    return FieldDefinition(
      name: name,
      type: type,
      required: data['required'] as bool? ?? false,
      description: data['description'] as String?,
      values: values,
    );
  }
}
