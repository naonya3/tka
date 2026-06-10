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

        test('does not declare title in fields (reserved top-level)', () {
          final yaml = loadYaml(projectTemplates[name]!) as Map;
          final def = ProjectDefinition.fromYaml(yaml);
          expect(def.fields.containsKey('title'), isFalse);
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

  group('tdd template gates', () {
    ProjectDefinition tdd() =>
        ProjectDefinition.fromYaml(loadYaml(projectTemplates['tdd']!) as Map);

    test('every forward transition is gated on test_cmd', () {
      final sm = tdd().stateMachine;
      expect(sm.getVerify('todo', 'red'), contains('TKA_TICKET_FIELD_TEST_CMD'));
      expect(sm.getVerify('red', 'green'), contains('TKA_TICKET_FIELD_TEST_CMD'));
      expect(sm.getVerify('green', 'done'), contains('TKA_TICKET_FIELD_TEST_CMD'));
      expect(sm.getVerify('refactor', 'done'),
          contains('TKA_TICKET_FIELD_TEST_CMD'));
    });

    test('todo gate demands a failing test, red gate a passing one', () {
      final sm = tdd().stateMachine;
      // todo→red refuses a passing test_cmd (no real failing test written)
      expect(sm.getVerify('todo', 'red'), contains('FAILING'));
      // backward transitions stay ungated
      expect(sm.getVerify('red', 'todo'), isNull);
      expect(sm.getVerify('green', 'refactor'), isNull);
    });
  });
}
