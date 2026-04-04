import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:tka/templates/project_templates.dart';
import 'package:tka/models/project_definition.dart';

void main() {
  group('projectTemplates', () {
    test('contains all 6 templates', () {
      expect(projectTemplates.length, 6);
      expect(projectTemplates.keys, containsAll([
        'sample', 'tdd', 'review-loop', 'bug-hunt', 'agent-harness', 'evolve',
      ]));
    });

    for (final name in [
      'sample', 'tdd', 'review-loop', 'bug-hunt', 'agent-harness', 'evolve',
    ]) {
      group(name, () {
        test('is valid YAML', () {
          final yaml = loadYaml(projectTemplates[name]!);
          expect(yaml, isA<Map>());
        });

        test('can be parsed by ProjectDefinition.fromYaml', () {
          final yaml = loadYaml(projectTemplates[name]!) as Map;
          final def = ProjectDefinition.fromYaml(yaml);
          expect(def.name, name);
        });

        test('has required title field', () {
          final yaml = loadYaml(projectTemplates[name]!) as Map;
          final def = ProjectDefinition.fromYaml(yaml);
          expect(def.fields.containsKey('title'), isTrue);
          expect(def.fields['title']!.required, isTrue);
        });

        test('has at least one state transition', () {
          final yaml = loadYaml(projectTemplates[name]!) as Map;
          final def = ProjectDefinition.fromYaml(yaml);
          expect(def.stateMachine.transitions.isNotEmpty, isTrue);
        });
      });
    }
  });

  group('templateDescriptions', () {
    test('has entry for every template', () {
      for (final name in projectTemplates.keys) {
        expect(templateDescriptions.containsKey(name), isTrue,
            reason: 'Missing description for $name');
      }
    });
  });
}
