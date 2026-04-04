import 'package:test/test.dart';
import 'package:tka/models/state_machine.dart';
import 'package:tka/validators/transition_validator.dart';

void main() {
  final sm = StateMachine(
    initial: 'backlog',
    transitions: {
      'backlog': ['in_progress'],
      'in_progress': ['review', 'blocked'],
      'blocked': ['in_progress'],
      'review': ['done', 'in_progress'],
    },
  );

  test('valid transition returns null', () {
    expect(TransitionValidator.validate(sm, 'backlog', 'in_progress'), isNull);
    expect(TransitionValidator.validate(sm, 'in_progress', 'review'), isNull);
    expect(TransitionValidator.validate(sm, 'review', 'done'), isNull);
  });

  test('invalid transition returns error with available transitions', () {
    final result = TransitionValidator.validate(sm, 'backlog', 'done');
    expect(result, isNotNull);
    expect(result, contains("Cannot transition from 'backlog' to 'done'"));
    expect(result, contains('in_progress'));
  });

  test('transition from terminal state returns error', () {
    final result = TransitionValidator.validate(sm, 'done', 'backlog');
    expect(result, isNotNull);
    expect(result, contains('terminal state'));
  });

  test('available transitions listed in error message', () {
    final result = TransitionValidator.validate(sm, 'in_progress', 'done');
    expect(result, isNotNull);
    expect(result, contains('review'));
    expect(result, contains('blocked'));
  });
}
