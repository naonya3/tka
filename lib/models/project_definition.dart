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
    final fieldsRaw = data['fields'] as Map;
    final fields = <String, FieldDefinition>{};
    for (final entry in fieldsRaw.entries) {
      final name = entry.key as String;
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
