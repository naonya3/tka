import 'package:test/test.dart';
import 'package:tka/helpers/ticket_id.dart';

void main() {
  group('parseTicketId', () {
    test('parses simple project-seq format', () {
      final (project, seq) = parseTicketId('todo-001');
      expect(project, equals('todo'));
      expect(seq, equals(1));
    });

    test('parses hyphenated project name', () {
      final (project, seq) = parseTicketId('game-dev-003');
      expect(project, equals('game-dev'));
      expect(seq, equals(3));
    });

    test('parses large seq numbers', () {
      final (project, seq) = parseTicketId('proj-1234');
      expect(project, equals('proj'));
      expect(seq, equals(1234));
    });

    test('throws on invalid format', () {
      expect(() => parseTicketId('noid'), throwsFormatException);
    });

    test('throws on empty string', () {
      expect(() => parseTicketId(''), throwsFormatException);
    });
  });
}
