import 'package:test/test.dart';
import 'package:tka/models/project_definition.dart';
import 'package:tka/models/field_definition.dart';


void main() {
  group('ProjectDefinition.fromYaml', () {
    final yamlMap = {
      'version': 1,
      'name': 'game-dev',
      'description': 'Game development project',
      'fields': {
        'title': {'type': 'string', 'required': true},
        'detail': {'type': 'string'},
        'history': {'type': 'list'},
      },
      'states': {
        'initial': 'backlog',
        'transitions': {
          'backlog': ['in_progress'],
          'in_progress': ['review', 'blocked'],
          'blocked': ['in_progress'],
          'review': ['done', 'in_progress'],
        },
      },
    };

    late ProjectDefinition def;

    setUp(() {
      def = ProjectDefinition.fromYaml(yamlMap);
    });

    test('name, version, description are set correctly', () {
      expect(def.version, 1);
      expect(def.name, 'game-dev');
      expect(def.description, 'Game development project');
    });

    test('fields are parsed as Map<String, FieldDefinition>', () {
      expect(def.fields.length, 3);
      expect(def.fields['title']!.type, FieldType.string);
      expect(def.fields['title']!.required, true);
      expect(def.fields['detail']!.type, FieldType.string);
      expect(def.fields['detail']!.required, false);
      expect(def.fields['history']!.type, FieldType.list);
    });

    test('stateMachine is parsed correctly', () {
      expect(def.stateMachine.initial, 'backlog');
      expect(def.stateMachine.canTransition('backlog', 'in_progress'), true);
      expect(def.stateMachine.canTransition('backlog', 'done'), false);
      expect(def.stateMachine.isTerminal('done'), true);
    });

    test('missing fields throws user-friendly error', () {
      expect(
        () => ProjectDefinition.fromYaml({'version': 1, 'name': 'x', 'states': {'initial': 'todo', 'transitions': {'todo': ['done']}}}),
        throwsA(predicate((e) => e is ArgumentError && e.message.contains('"fields" is required'))),
      );
    });

    test('missing states throws user-friendly error', () {
      expect(
        () => ProjectDefinition.fromYaml({'version': 1, 'name': 'x', 'fields': {'title': {'type': 'string'}}}),
        throwsA(predicate((e) => e is ArgumentError && e.message.contains('"states" is required'))),
      );
    });

    test('missing states.initial throws user-friendly error', () {
      expect(
        () => ProjectDefinition.fromYaml({'version': 1, 'name': 'x', 'fields': {'title': {'type': 'string'}}, 'states': {'transitions': {'todo': ['done']}}}),
        throwsA(predicate((e) => e is ArgumentError && e.message.contains('"states.initial" is required'))),
      );
    });

    test('missing states.transitions throws user-friendly error', () {
      expect(
        () => ProjectDefinition.fromYaml({'version': 1, 'name': 'x', 'fields': {'title': {'type': 'string'}}, 'states': {'initial': 'todo'}}),
        throwsA(predicate((e) => e is ArgumentError && e.message.contains('"states.transitions" is required'))),
      );
    });

    test('empty schema throws user-friendly error', () {
      expect(
        () => ProjectDefinition.fromYaml({'version': 1, 'name': 'x'}),
        throwsA(predicate((e) => e is ArgumentError && e.message.contains('"fields" is required'))),
      );
    });

    test('minimal definition works', () {
      final minimal = {
        'version': 1,
        'name': 'minimal',
        'fields': {
          'title': {'type': 'string', 'required': true},
        },
        'states': {
          'initial': 'todo',
          'transitions': {
            'todo': ['done'],
          },
        },
      };
      final d = ProjectDefinition.fromYaml(minimal);
      expect(d.name, 'minimal');
      expect(d.description, '');
      expect(d.fields.length, 1);
      expect(d.stateMachine.initial, 'todo');
    });
  });
}
