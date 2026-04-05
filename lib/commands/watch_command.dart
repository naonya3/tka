import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../store/project_store.dart';
import '../store/ticket_store.dart';
import 'watch_renderer.dart';

class WatchCommand extends Command<void> {
  @override
  final String name = 'watch';
  @override
  final String description = '''Real-time ticket dashboard. Ctrl+C or q to exit.

Usage: tka watch [--project <name>]
Output: ANSI terminal UI (not JSON). Updates on file changes.
Runs in alternate screen buffer (like vim).
TAB: switch project  1-9: toggle status filter  0: reset filters  q: quit''';

  final ProjectStore projectStore;
  final TicketStore ticketStore;
  final String dataPath;

  WatchCommand({
    required this.projectStore,
    required this.ticketStore,
    required this.dataPath,
  }) {
    argParser.addOption('project', abbr: 'p', help: 'Initial project to show');
  }

  @override
  Future<void> run() async {
    final projectNames = projectStore.list()..sort(); // Fix #2: sorted
    if (projectNames.isEmpty) {
      stderr.writeln('No projects found.');
      return;
    }

    var projectIndex = 0;
    final initialProject = argResults!['project'] as String?;
    if (initialProject != null) {
      final idx = projectNames.indexOf(initialProject);
      if (idx >= 0) projectIndex = idx;
    }

    var statuses = _getStatuses(projectNames[projectIndex]);
    var activeFilters = _defaultFilters(projectNames[projectIndex], statuses);

    stdout.write('\x1B[?1049h\x1B[?25l');

    void cleanup() {
      stdout.write('\x1B[?25h\x1B[0m\x1B[?1049l');
    }

    try {
      ProcessSignal.sigint.watch().listen((_) {
        cleanup();
        exit(0);
      });
    } catch (_) {}

    void render() {
      final name = projectNames[projectIndex];
      final allTickets = ticketStore.listAll(name);

      var filtered = activeFilters.isEmpty
          ? allTickets
          : allTickets.where((t) => activeFilters.contains(t.status)).toList();

      final ticketData = filtered
          .map((t) => WatchTicketData(
                id: t.id,
                status: t.status,
                title: (t.fields['title'] as String?) ?? '',
              ))
          .toList();

      final width = _getTerminalWidth();
      stdout.write('\x1B[2J\x1B[H');
      stdout.write(renderDashboard(
        projectName: name,
        tickets: ticketData,
        projectNames: projectNames,
        projectIndex: projectIndex,
        activeFilters: activeFilters,
        statuses: statuses,
        width: width,
      ));
    }

    render();

    // File watcher
    final ticketRoot = Directory(dataPath).parent;
    Timer? debounce;
    StreamSubscription? watchSub;
    if (ticketRoot.existsSync()) {
      watchSub = ticketRoot.watch(recursive: true).listen((event) {
        if (event.path.endsWith('.tmp') || event.path.endsWith('.lock')) return;
        debounce?.cancel();
        debounce = Timer(Duration(milliseconds: 300), render);
      });
    }

    stdin.echoMode = false;
    stdin.lineMode = false;

    final completer = Completer<void>();

    stdin.listen((bytes) {
      final seq = String.fromCharCodes(bytes);

      if (seq == 'q' || bytes.first == 3) {
        cleanup();
        stdin.echoMode = true;
        stdin.lineMode = true;
        watchSub?.cancel();
        exit(0);
      }

      if (seq == '\t') {
        // TAB: next project
        projectIndex = (projectIndex + 1) % projectNames.length;
        statuses = _getStatuses(projectNames[projectIndex]);
        activeFilters = _defaultFilters(projectNames[projectIndex], statuses);
        render();
      } else if (seq == '\x1B[Z') {
        // Shift+TAB: prev project
        projectIndex =
            (projectIndex - 1 + projectNames.length) % projectNames.length;
        statuses = _getStatuses(projectNames[projectIndex]);
        activeFilters = _defaultFilters(projectNames[projectIndex], statuses);
        render();
      } else if (seq.length == 1 && seq == '0') {
        // 0: reset filters to default
        activeFilters = _defaultFilters(projectNames[projectIndex], statuses);
        render();
      } else if (seq.length == 1) {
        final n = int.tryParse(seq);
        if (n != null && n >= 1 && n <= statuses.length) {
          final status = statuses[n - 1];
          if (activeFilters.contains(status)) {
            activeFilters.remove(status);
          } else {
            activeFilters.add(status);
          }
          render();
        }
      }
    });

    await completer.future;
  }

  Set<String> _defaultFilters(String projectName, List<String> statuses) {
    try {
      final def = projectStore.load(projectName);
      final sm = def.stateMachine;
      return statuses.where((s) => !sm.isTerminal(s)).toSet();
    } catch (_) {
      return statuses.toSet();
    }
  }

  List<String> _getStatuses(String projectName) {
    try {
      final def = projectStore.load(projectName);
      return getStatusesFromDefinition(def);
    } catch (_) {
      return [];
    }
  }

  int _getTerminalWidth() {
    try {
      return stdout.terminalColumns;
    } catch (_) {
      return 80;
    }
  }
}

/// Extracts ordered status list from a project definition.
List<String> getStatusesFromDefinition(
    dynamic def) {
  final sm = def.stateMachine;
  final all = <String>{sm.initial};
  for (final entry in sm.transitions.entries) {
    all.add(entry.key);
    all.addAll(entry.value);
  }
  return all.toList();
}

/// Manages watch dashboard filter state.
class WatchFilterState {
  final List<String> projectNames;
  int projectIndex;
  List<String> statuses;
  Set<String> activeFilters;

  WatchFilterState({
    required this.projectNames,
    this.projectIndex = 0,
    required this.statuses,
    required this.activeFilters,
  });

  String get currentProject => projectNames[projectIndex];

  void nextProject() {
    projectIndex = (projectIndex + 1) % projectNames.length;
  }

  void prevProject() {
    projectIndex = (projectIndex - 1 + projectNames.length) % projectNames.length;
  }

  void toggleFilter(int index) {
    if (index < 0 || index >= statuses.length) return;
    final status = statuses[index];
    if (activeFilters.contains(status)) {
      activeFilters.remove(status);
    } else {
      activeFilters.add(status);
    }
  }

  void resetFilters(Set<String> defaults) {
    activeFilters = defaults;
  }
}
