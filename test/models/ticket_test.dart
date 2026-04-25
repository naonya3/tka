import 'package:test/test.dart';
import 'package:tka/models/ticket.dart';

void main() {
  final sampleJson = {
    'id': 'game-dev-003',
    'project': 'game-dev',
    'seq': 3,
    'title': 'Implement login feature',
    'status': 'in_progress',
    'fields': {
      'detail': 'Add OAuth2 authentication flow',
      'prompt': null,
      'history': [
        '2026-04-01: Initial design done',
        '2026-04-03: Prototype verified',
      ],
    },
    'created_at': '2026-04-01T10:00:00+09:00',
    'updated_at': '2026-04-04T14:30:00+09:00',
  };

  group('Ticket.fromJson', () {
    test('parses all fields correctly', () {
      final t = Ticket.fromJson(sampleJson);
      expect(t.project, 'game-dev');
      expect(t.seq, 3);
      expect(t.title, 'Implement login feature');
      expect(t.status, 'in_progress');
      expect(t.fields['detail'], 'Add OAuth2 authentication flow');
      expect(t.createdAt, DateTime.parse('2026-04-01T10:00:00+09:00'));
      expect(t.updatedAt, DateTime.parse('2026-04-04T14:30:00+09:00'));
    });

    test('parses null field values', () {
      final t = Ticket.fromJson(sampleJson);
      expect(t.fields.containsKey('prompt'), isTrue);
      expect(t.fields['prompt'], isNull);
    });

    test('parses list fields as List<String>', () {
      final t = Ticket.fromJson(sampleJson);
      final history = t.fields['history'];
      expect(history, isA<List>());
      expect(history, hasLength(2));
      expect(history[0], '2026-04-01: Initial design done');
      expect(history[1], '2026-04-03: Prototype verified');
    });

    test('parses timestamps correctly', () {
      final t = Ticket.fromJson(sampleJson);
      expect(t.createdAt.year, 2026);
      expect(t.createdAt.month, 4);
      expect(t.createdAt.day, 1);
      expect(t.updatedAt.year, 2026);
      expect(t.updatedAt.month, 4);
      expect(t.updatedAt.day, 4);
    });
  });

  group('Ticket.id', () {
    test('is computed as project-seq with zero padding', () {
      final t = Ticket.fromJson(sampleJson);
      expect(t.id, 'game-dev-003');
    });

    test('pads single digit seq', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['seq'] = 1;
      json['project'] = 'todo';
      final t = Ticket.fromJson(json);
      expect(t.id, 'todo-001');
    });

    test('handles seq over 999', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['seq'] = 1234;
      final t = Ticket.fromJson(json);
      expect(t.id, 'game-dev-1234');
    });
  });

  group('Ticket.fileName', () {
    test('returns zero-padded seq with .json', () {
      final t = Ticket.fromJson(sampleJson);
      expect(t.fileName, '003.json');
    });

    test('handles seq over 999', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['seq'] = 1234;
      final t = Ticket.fromJson(json);
      expect(t.fileName, '1234.json');
    });
  });

  group('Ticket.toJson', () {
    test('serializes back correctly (round-trip)', () {
      final t = Ticket.fromJson(sampleJson);
      final json = t.toJson();
      expect(json['id'], 'game-dev-003');
      expect(json['project'], 'game-dev');
      expect(json['seq'], 3);
      expect(json['title'], 'Implement login feature');
      expect(json['status'], 'in_progress');
      expect(json['fields']['prompt'], isNull);
      expect(json['fields']['history'], hasLength(2));
      expect(json['created_at'], '2026-04-01T10:00:00+09:00');
      expect(json['updated_at'], '2026-04-04T14:30:00+09:00');
    });

    test('round-trip preserves data', () {
      final t1 = Ticket.fromJson(sampleJson);
      final t2 = Ticket.fromJson(t1.toJson());
      expect(t2.id, t1.id);
      expect(t2.project, t1.project);
      expect(t2.seq, t1.seq);
      expect(t2.title, t1.title);
      expect(t2.status, t1.status);
      expect(t2.fields['prompt'], t1.fields['prompt']);
      expect(t2.createdAt, t1.createdAt);
      expect(t2.updatedAt, t1.updatedAt);
    });
  });
}
