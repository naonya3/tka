import 'package:test/test.dart';
import 'package:tka/commands/watch_renderer.dart';

void main() {
  group('renderDashboard', () {
    test('renders single project with tickets', () {
      final result = renderDashboard(
        projectName: 'my-project',
        tickets: [
          WatchTicketData(id: 'my-project-001', status: 'todo', title: 'First'),
          WatchTicketData(id: 'my-project-002', status: 'done', title: 'Second'),
        ],
        projectNames: ['my-project'],
        projectIndex: 0,
        activeFilters: {},
        statuses: ['todo', 'done'],
      );
      expect(result, contains('my-project'));
      expect(result, contains('my-project-001'));
      expect(result, contains('First'));
      expect(result, contains('todo'));
    });

    test('shows navigation when multiple projects', () {
      final result = renderDashboard(
        projectName: 'beta',
        tickets: [],
        projectNames: ['alpha', 'beta', 'gamma'],
        projectIndex: 1,
        activeFilters: {},
        statuses: ['todo'],
      );
      expect(result, contains('alpha'));
      expect(result, contains('beta'));
      expect(result, contains('gamma'));
    });

    test('shows status filter bar with numbers', () {
      final result = renderDashboard(
        projectName: 'p',
        tickets: [],
        projectNames: ['p'],
        projectIndex: 0,
        activeFilters: {'in_progress'},
        statuses: ['todo', 'in_progress', 'done'],
      );
      expect(result, contains('1:todo'));
      expect(result, contains('2:in_progress'));
      expect(result, contains('3:done'));
    });

    test('shows empty state message', () {
      final result = renderDashboard(
        projectName: 'p',
        tickets: [],
        projectNames: ['p'],
        projectIndex: 0,
        activeFilters: {},
        statuses: [],
      );
      expect(result, contains('No tickets'));
    });

    test('shows keybindings footer', () {
      final result = renderDashboard(
        projectName: 'p',
        tickets: [],
        projectNames: ['p'],
        projectIndex: 0,
        activeFilters: {},
        statuses: [],
      );
      expect(result, contains('q:quit'));
    });

    test('title truncation works', () {
      final result = renderDashboard(
        projectName: 'p',
        tickets: [
          WatchTicketData(id: 'p-001', status: 'todo', title: 'A' * 200),
        ],
        projectNames: ['p'],
        projectIndex: 0,
        activeFilters: {},
        statuses: ['todo'],
        width: 60,
      );
      expect(result, contains('...'));
    });
  });

  group('displayWidth', () {
    test('ASCII is width 1 per char', () {
      expect(displayWidth('hello'), equals(5));
    });

    test('CJK characters are width 2', () {
      expect(displayWidth('日本語'), equals(6));
    });

    test('mixed ASCII and CJK', () {
      expect(displayWidth('abcテスト'), equals(9));
    });
  });
}
