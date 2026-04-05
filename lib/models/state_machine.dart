class StateMachine {
  final String initial;
  final Map<String, List<String>> transitions;
  final Map<String, String> _verifyCommands; // key: "from->to"

  StateMachine({
    required this.initial,
    required this.transitions,
    Map<String, String>? verifyCommands,
  }) : _verifyCommands = verifyCommands ?? {};

  factory StateMachine.fromYaml(Map data) {
    final transitionsRaw = data['transitions'] as Map;
    final transitions = <String, List<String>>{};
    final verifyCommands = <String, String>{};

    for (final entry in transitionsRaw.entries) {
      final from = entry.key as String;
      final value = entry.value;

      if (value is List) {
        // Simple format: todo: [in_progress, done]
        transitions[from] = value.cast<String>().toList();
      } else if (value is Map) {
        // Verify format: red: { targets: [green], verify: "dart test" }
        final targets = (value['targets'] as List).cast<String>().toList();
        transitions[from] = targets;
        final verify = value['verify'] as String?;
        if (verify != null) {
          for (final target in targets) {
            verifyCommands['$from->$target'] = verify;
          }
        }
      } else {
        throw ArgumentError(
            'Invalid transition format for state "$from". '
            'Expected a list of targets or a map with "targets" and optional "verify".');
      }
    }

    return StateMachine(
      initial: data['initial'] as String,
      transitions: transitions,
      verifyCommands: verifyCommands,
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

  /// Returns the verify command for a transition, or null if none.
  String? getVerify(String from, String to) {
    return _verifyCommands['$from->$to'];
  }
}
