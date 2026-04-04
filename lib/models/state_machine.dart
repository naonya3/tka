class StateMachine {
  final String initial;
  final Map<String, List<String>> transitions;

  StateMachine({required this.initial, required this.transitions});

  factory StateMachine.fromYaml(Map data) {
    final transitionsRaw = data['transitions'] as Map;
    final transitions = <String, List<String>>{};
    for (final entry in transitionsRaw.entries) {
      transitions[entry.key as String] =
          (entry.value as List).cast<String>().toList();
    }
    return StateMachine(
      initial: data['initial'] as String,
      transitions: transitions,
    );
  }

  bool canTransition(String from, String to) {
    final targets = transitions[from];
    if (targets == null) return false;
    return targets.contains(to);
  }

  List<String> getAvailableTransitions(String from) {
    return transitions[from] ?? [];
  }

  bool isTerminal(String state) {
    return !transitions.containsKey(state);
  }
}
