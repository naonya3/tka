import 'package:test/test.dart';
import 'package:tka/models/state_machine.dart';

void main() {
  group('StateMachine', () {
    late StateMachine gameDev;
    late StateMachine simpleTodo;

    setUp(() {
      gameDev = StateMachine.fromYaml({
        'initial': 'backlog',
        'transitions': {
          'backlog': ['in_progress'],
          'in_progress': ['review', 'blocked'],
          'blocked': ['in_progress'],
          'review': ['done', 'in_progress'],
        },
      });

      simpleTodo = StateMachine.fromYaml({
        'initial': 'todo',
        'transitions': {
          'todo': ['done'],
        },
      });
    });

    test('parses from YAML map', () {
      expect(gameDev.initial, equals('backlog'));
      expect(gameDev.transitions, containsPair('backlog', ['in_progress']));
      expect(
        gameDev.transitions,
        containsPair('in_progress', ['review', 'blocked']),
      );
      expect(gameDev.transitions, containsPair('blocked', ['in_progress']));
      expect(
        gameDev.transitions,
        containsPair('review', ['done', 'in_progress']),
      );
    });

    test('canTransition returns true for valid transitions', () {
      expect(gameDev.canTransition('backlog', 'in_progress'), isTrue);
      expect(gameDev.canTransition('in_progress', 'review'), isTrue);
      expect(gameDev.canTransition('in_progress', 'blocked'), isTrue);
      expect(gameDev.canTransition('blocked', 'in_progress'), isTrue);
      expect(gameDev.canTransition('review', 'done'), isTrue);
      expect(gameDev.canTransition('review', 'in_progress'), isTrue);
    });

    test('canTransition returns false for invalid transitions', () {
      expect(gameDev.canTransition('backlog', 'done'), isFalse);
      expect(gameDev.canTransition('backlog', 'review'), isFalse);
      expect(gameDev.canTransition('in_progress', 'backlog'), isFalse);
      expect(gameDev.canTransition('review', 'backlog'), isFalse);
    });

    test('terminal states have no transitions', () {
      expect(gameDev.canTransition('done', 'backlog'), isFalse);
      expect(gameDev.canTransition('done', 'in_progress'), isFalse);
      expect(gameDev.canTransition('done', 'review'), isFalse);
      expect(gameDev.canTransition('done', 'done'), isFalse);
    });

    test('getAvailableTransitions returns correct list', () {
      expect(
        gameDev.getAvailableTransitions('backlog'),
        equals(['in_progress']),
      );
      expect(
        gameDev.getAvailableTransitions('in_progress'),
        equals(['review', 'blocked']),
      );
      expect(
        gameDev.getAvailableTransitions('review'),
        equals(['done', 'in_progress']),
      );
      expect(gameDev.getAvailableTransitions('done'), isEmpty);
    });

    test('isTerminal identifies terminal states', () {
      expect(gameDev.isTerminal('done'), isTrue);
      expect(gameDev.isTerminal('backlog'), isFalse);
      expect(gameDev.isTerminal('in_progress'), isFalse);
      expect(gameDev.isTerminal('review'), isFalse);
      expect(gameDev.isTerminal('blocked'), isFalse);
    });

    test('initial state is set correctly', () {
      expect(gameDev.initial, equals('backlog'));
      expect(simpleTodo.initial, equals('todo'));
    });

    test('simple two-state machine works', () {
      expect(simpleTodo.initial, equals('todo'));
      expect(simpleTodo.canTransition('todo', 'done'), isTrue);
      expect(simpleTodo.canTransition('done', 'todo'), isFalse);
      expect(simpleTodo.getAvailableTransitions('todo'), equals(['done']));
      expect(simpleTodo.getAvailableTransitions('done'), isEmpty);
      expect(simpleTodo.isTerminal('done'), isTrue);
      expect(simpleTodo.isTerminal('todo'), isFalse);
    });

    test('getVerify returns null for transitions without verify', () {
      expect(gameDev.getVerify('backlog', 'in_progress'), isNull);
    });

    test('getVerify returns null for simple list transitions', () {
      expect(simpleTodo.getVerify('todo', 'done'), isNull);
    });

    group('verify transitions', () {
      late StateMachine withVerify;

      setUp(() {
        withVerify = StateMachine.fromYaml({
          'initial': 'todo',
          'transitions': {
            'todo': ['red'],
            'red': {
              'targets': ['green'],
              'verify': 'dart test --reporter json',
            },
            'green': {
              'targets': ['refactor'],
              'verify': 'dart test',
            },
            'refactor': ['done'],
          },
        });
      });

      test('parses mixed simple and verify transitions', () {
        expect(withVerify.canTransition('todo', 'red'), isTrue);
        expect(withVerify.canTransition('red', 'green'), isTrue);
        expect(withVerify.canTransition('green', 'refactor'), isTrue);
        expect(withVerify.canTransition('refactor', 'done'), isTrue);
      });

      test('getVerify returns command for verify transitions', () {
        expect(withVerify.getVerify('red', 'green'),
            equals('dart test --reporter json'));
        expect(withVerify.getVerify('green', 'refactor'),
            equals('dart test'));
      });

      test('getVerify returns null for simple transitions', () {
        expect(withVerify.getVerify('todo', 'red'), isNull);
        expect(withVerify.getVerify('refactor', 'done'), isNull);
      });

      test('getAvailableTransitions works with verify format', () {
        expect(withVerify.getAvailableTransitions('red'), equals(['green']));
        expect(withVerify.getAvailableTransitions('green'),
            equals(['refactor']));
      });

      test('isTerminal works with verify format', () {
        expect(withVerify.isTerminal('done'), isTrue);
        expect(withVerify.isTerminal('red'), isFalse);
      });
    });
  });
}
