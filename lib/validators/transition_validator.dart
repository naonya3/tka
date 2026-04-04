import '../models/state_machine.dart';

class TransitionValidator {
  static String? validate(
      StateMachine sm, String currentState, String targetState) {
    if (sm.canTransition(currentState, targetState)) return null;
    if (sm.isTerminal(currentState)) {
      return "'$currentState' is a terminal state. No transitions allowed.";
    }
    final available = sm.getAvailableTransitions(currentState);
    return "Cannot transition from '$currentState' to '$targetState'. Available: ${available.join(', ')}";
  }
}
