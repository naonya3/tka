import 'field_definition.dart';
import 'state_machine.dart';

class ProjectDefinition {
  final int version;
  final String name;
  final String description;
  final Map<String, FieldDefinition> fields;
  final StateMachine stateMachine;

  ProjectDefinition({
    required this.version,
    required this.name,
    required this.description,
    required this.fields,
    required this.stateMachine,
  });

  factory ProjectDefinition.fromYaml(Map data) {
    if (!data.containsKey('fields')) {
      throw ArgumentError('Schema error: "fields" is required.');
    }
    if (data['fields'] != null && data['fields'] is! Map) {
      throw ArgumentError('Schema error: "fields" must be a map.');
    }
    if (data['states'] == null) {
      throw ArgumentError('Schema error: "states" is required.');
    }
    if (data['states'] is! Map) {
      throw ArgumentError('Schema error: "states" must be a map.');
    }
    final statesRaw = data['states'] as Map;
    if (statesRaw['initial'] == null) {
      throw ArgumentError('Schema error: "states.initial" is required.');
    }
    if (statesRaw['transitions'] == null) {
      throw ArgumentError('Schema error: "states.transitions" is required.');
    }
    if (statesRaw['transitions'] is! Map) {
      throw ArgumentError('Schema error: "states.transitions" must be a map.');
    }
    final fieldsRaw = (data['fields'] as Map?) ?? const {};
    if (fieldsRaw.containsKey('title')) {
      throw ArgumentError(
          'Schema error: "title" is a reserved top-level property and cannot be defined in fields. '
          'Every ticket has a built-in required "title" — remove it from your schema. '
          'Run "tka migrate" to upgrade legacy projects.');
    }
    final fields = <String, FieldDefinition>{};
    for (final entry in fieldsRaw.entries) {
      final name = entry.key as String;
      if (entry.value is! Map) {
        throw ArgumentError('Schema error: field "$name" must be a map with at least a "type" property.');
      }
      fields[name] = FieldDefinition.fromYaml(name, entry.value as Map);
    }
    return ProjectDefinition(
      version: data['version'] as int,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      fields: fields,
      stateMachine: StateMachine.fromYaml(data['states'] as Map),
    );
  }
}
