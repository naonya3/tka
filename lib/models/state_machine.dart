class StateMachine {
  final String initial;
  final Map<String, List<String>> transitions;
  final Map<String, String> _verifyCommands; // key: "from->to"
  final Map<String, String> _descriptions; // key: source state

  StateMachine({
    required this.initial,
    required this.transitions,
    Map<String, String>? verifyCommands,
    Map<String, String>? descriptions,
  })  : _verifyCommands = verifyCommands ?? {},
        _descriptions = descriptions ?? {};

  factory StateMachine.fromYaml(Map data) {
    final transitionsRaw = data['transitions'] as Map;
    final transitions = <String, List<String>>{};
    final verifyCommands = <String, String>{};
    final descriptions = <String, String>{};

    for (final entry in transitionsRaw.entries) {
      final from = entry.key as String;
      final value = entry.value;

      if (value is List) {
        // Simple format: todo: [in_progress, done]
        transitions[from] = value.cast<String>().toList();
      } else if (value is Map) {
        // Map format: red: { targets: [green], verify: { green: "dart test" }, description: "..." }
        final targets = (value['targets'] as List).cast<String>().toList();
        transitions[from] = targets;
        final verify = value['verify'];
        if (verify is Map) {
          for (final vEntry in verify.entries) {
            verifyCommands['$from->${vEntry.key}'] = vEntry.value as String;
          }
        }
        final description = value['description'];
        if (description is String) {
          descriptions[from] = description;
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
      descriptions: descriptions,
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

  /// Returns the description for transitions from a state, or null if none.
  String? getDescription(String from) {
    return _descriptions[from];
  }

  /// Returns transitions as JSON-friendly map, including verify info.
  ///
  /// States with verify commands are serialized as:
  ///   `{"targets": [...], "verify": {"target": "command"}}`
  /// States without verify remain as simple lists: `[...]`
  Map<String, dynamic> toTransitionsJson() {
    final result = <String, dynamic>{};
    for (final entry in transitions.entries) {
      final from = entry.key;
      final targets = entry.value;
      // Collect verify commands for this source state
      final verify = <String, String>{};
      for (final target in targets) {
        final cmd = _verifyCommands['$from->$target'];
        if (cmd != null) {
          verify[target] = cmd;
        }
      }
      final description = _descriptions[from];
      if (verify.isEmpty && description == null) {
        result[from] = targets;
      } else {
        final map = <String, dynamic>{'targets': targets};
        if (description != null) map['description'] = description;
        if (verify.isNotEmpty) map['verify'] = verify;
        result[from] = map;
      }
    }
    return result;
  }
}
