import 'dart:io';
import '../models/field_definition.dart';

(String, String) parseSetOption(String input) {
  final idx = input.indexOf('=');
  if (idx < 0) {
    throw FormatException('Invalid --set format: $input (expected field=value)');
  }
  final key = input.substring(0, idx);
  if (key.isEmpty) {
    throw FormatException('Invalid --set format: field name cannot be empty');
  }
  return (key, input.substring(idx + 1));
}

dynamic coerceValue(String raw, FieldDefinition def) {
  switch (def.type) {
    case FieldType.number:
      if (raw.isEmpty) return '';
      final n = num.tryParse(raw);
      if (n == null || n.isNaN || n.isInfinite) {
        throw FormatException('Invalid number: $raw');
      }
      return n;
    case FieldType.list:
      return [raw];
    default:
      return raw;
  }
}

Map<String, dynamic> buildFieldsFromSetOptions(
  List<String> setOptions,
  Map<String, FieldDefinition> fieldDefs,
) {
  final fields = <String, dynamic>{};
  for (final opt in setOptions) {
    final (name, rawValue) = parseSetOption(opt);
    if (!fieldDefs.containsKey(name)) {
      throw ArgumentError('Unknown field: $name');
    }
    final def = fieldDefs[name]!;
    if (def.type == FieldType.list) {
      throw ArgumentError('Cannot set list field "$name" with --set. Use "append" command instead.');
    }
    String? resolved =
        (def.type == FieldType.string || def.type == FieldType.date || def.type == FieldType.enumType)
            ? resolveFieldValue(rawValue)
            : rawValue;
    fields[name] = coerceValue(resolved!, def);
  }
  return fields;
}

/// Extracts the reserved "title" key from --set options.
/// Returns (resolvedTitle, remainingOptions). If title is not present,
/// resolvedTitle is null.
(String?, List<String>) extractTitleFromSetOptions(List<String> setOptions) {
  String? title;
  final remaining = <String>[];
  for (final opt in setOptions) {
    final idx = opt.indexOf('=');
    if (idx < 0) {
      remaining.add(opt);
      continue;
    }
    final key = opt.substring(0, idx);
    if (key != 'title') {
      remaining.add(opt);
      continue;
    }
    final resolved = resolveFieldValue(opt.substring(idx + 1));
    if (resolved == null || resolved.trim().isEmpty) {
      throw FormatException('title cannot be empty');
    }
    title = resolved;
  }
  return (title, remaining);
}

String? resolveFieldValue(String? raw) {
  if (raw == null) return null;
  if (raw == '-') {
    final buf = StringBuffer();
    String? line;
    var first = true;
    while ((line = stdin.readLineSync()) != null) {
      if (!first) buf.write('\n');
      buf.write(line);
      first = false;
    }
    return buf.toString();
  }
  if (raw == '@') {
    throw FormatException('Invalid value: bare @ is not allowed. Use @@ for literal @, or @path for file reference.');
  }
  if (raw.startsWith('@@')) {
    return raw.substring(1);
  }
  if (raw.startsWith('@')) {
    final path = raw.substring(1);
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.notFound) {
      throw Exception('File not found: $path');
    }
    if (entity != FileSystemEntityType.file) {
      throw Exception('Not a file: $path');
    }
    final file = File(path);
    return file.readAsStringSync();
  }
  return raw;
}
