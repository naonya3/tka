import 'dart:io';

import 'package:test/test.dart';
import 'package:tka/commands/watch_command.dart';
import 'package:tka/store/project_store.dart';

void main() {
  group('WatchFilterState', () {
    test('nextProject cycles forward', () {
      final state = WatchFilterState(
        projectNames: ['a', 'b', 'c'],
        projectIndex: 0,
        statuses: [],
        activeFilters: {},
      );
      state.nextProject();
      expect(state.currentProject, equals('b'));
      state.nextProject();
      expect(state.currentProject, equals('c'));
      state.nextProject();
      expect(state.currentProject, equals('a'));
    });

    test('prevProject cycles backward', () {
      final state = WatchFilterState(
        projectNames: ['a', 'b', 'c'],
        projectIndex: 0,
        statuses: [],
        activeFilters: {},
      );
      state.prevProject();
      expect(state.currentProject, equals('c'));
      state.prevProject();
      expect(state.currentProject, equals('b'));
    });

    test('toggleFilter adds and removes status', () {
      final state = WatchFilterState(
        projectNames: ['proj'],
        statuses: ['todo', 'doing', 'done'],
        activeFilters: {'todo', 'doing'},
      );
      state.toggleFilter(2);
      expect(state.activeFilters, equals({'todo', 'doing', 'done'}));
      state.toggleFilter(0);
      expect(state.activeFilters, equals({'doing', 'done'}));
    });

    test('toggleFilter ignores out-of-range index', () {
      final state = WatchFilterState(
        projectNames: ['proj'],
        statuses: ['todo', 'doing'],
        activeFilters: {'todo'},
      );
      state.toggleFilter(-1);
      state.toggleFilter(5);
      expect(state.activeFilters, equals({'todo'}));
    });

    test('resetFilters replaces current filters', () {
      final state = WatchFilterState(
        projectNames: ['proj'],
        statuses: ['todo', 'doing', 'done'],
        activeFilters: {'done'},
      );
      state.resetFilters({'todo', 'doing'});
      expect(state.activeFilters, equals({'todo', 'doing'}));
    });

    test('currentProject returns correct name', () {
      final state = WatchFilterState(
        projectNames: ['alpha', 'beta'],
        projectIndex: 1,
        statuses: [],
        activeFilters: {},
      );
      expect(state.currentProject, equals('beta'));
    });

    test('single project cycles to itself', () {
      final state = WatchFilterState(
        projectNames: ['only'],
        projectIndex: 0,
        statuses: [],
        activeFilters: {},
      );
      state.nextProject();
      expect(state.currentProject, equals('only'));
      state.prevProject();
      expect(state.currentProject, equals('only'));
    });
  });

  group('getStatusesFromDefinition', () {
    late Directory tmpDir;
    late ProjectStore projectStore;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('watch_cmd_test_');
      projectStore = ProjectStore(tmpDir.path);
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('extracts all statuses from project definition', () {
      File('${tmpDir.path}/myproj.yaml').writeAsStringSync('''
version: 2
name: myproj
description: test
fields:
  detail:
    type: string
states:
  initial: todo
  transitions:
    todo: [implementing]
    implementing: [testing, todo]
    testing: [done]
    done: [released]
''');
      final def = projectStore.load('myproj');
      final statuses = getStatusesFromDefinition(def);
      expect(statuses, containsAll(['todo', 'implementing', 'testing', 'done', 'released']));
    });

    test('includes initial state even without transitions from it', () {
      File('${tmpDir.path}/simple.yaml').writeAsStringSync('''
version: 2
name: simple
description: test
fields:
  detail:
    type: string
states:
  initial: open
  transitions:
    open: [closed]
''');
      final def = projectStore.load('simple');
      final statuses = getStatusesFromDefinition(def);
      expect(statuses, contains('open'));
      expect(statuses, contains('closed'));
    });
  });
}
