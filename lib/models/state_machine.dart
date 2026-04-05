class StateMachine {
  final String initial;
  final Map<String, List<String>> transitions;
  final Map<String, String> _verifyCommands; // key: "from->to"
  final Map<String, String> _hints; // key: "from->to"
  final Map<String, String> _guides; // key: state name

  StateMachine({
    required this.initial,
    required this.transitions,
    Map<String, String>? verifyCommands,
    Map<String, String>? hints,
    Map<String, String>? guides,
  })  : _verifyCommands = verifyCommands ?? {},
        _hints = hints ?? {},
        _guides = guides ?? {};

  factory StateMachine.fromYaml(Map data) {
    final transitionsRaw = data['transitions'] as Map;
    final transitions = <String, List<String>>{};
    final verifyCommands = <String, String>{};
    final hints = <String, String>{};
    final guides = <String, String>{};

    // Parse guide section (state-level descriptions)
    final guideRaw = data['guide'];
    if (guideRaw is Map) {
      for (final entry in guideRaw.entries) {
        guides[entry.key as String] = entry.value as String;
      }
    }

    for (final entry in transitionsRaw.entries) {
      final from = entry.key as String;
      final value = entry.value;

      if (value is List) {
        // Simple format: todo: [in_progress, done]
        transitions[from] = value.cast<String>().toList();
      } else if (value is Map) {
        // Map format: red: { targets: [green], hint: {...}, verify: {...} }
        final targets = (value['targets'] as List).cast<String>().toList();
        transitions[from] = targets;
        final verify = value['verify'];
        if (verify is Map) {
          for (final vEntry in verify.entries) {
            verifyCommands['$from->${vEntry.key}'] = vEntry.value as String;
          }
        }
        final hint = value['hint'];
        if (hint is Map) {
          for (final hEntry in hint.entries) {
            hints['$from->${hEntry.key}'] = hEntry.value as String;
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
      hints: hints,
      guides: guides,
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

  /// Returns the hint for a specific transition, or null if none.
  String? getHint(String from, String to) {
    return _hints['$from->$to'];
  }

  /// Returns the guide for a state, or null if none.
  String? getGuide(String state) {
    return _guides[state];
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
      // Collect hints for this source state
      final hint = <String, String>{};
      for (final target in targets) {
        final h = _hints['$from->$target'];
        if (h != null) {
          hint[target] = h;
        }
      }
      if (verify.isEmpty && hint.isEmpty) {
        result[from] = targets;
      } else {
        final map = <String, dynamic>{'targets': targets};
        if (hint.isNotEmpty) map['hint'] = hint;
        if (verify.isNotEmpty) map['verify'] = verify;
        result[from] = map;
      }
    }
    return result;
  }
}
