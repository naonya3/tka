import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tka/models/ticket.dart';
import 'package:tka/store/ticket_store.dart';

Ticket _makeTicket(String project, int seq, String status,
    {String updatedAtRaw = '2026-04-01T10:00:00+09:00'}) {
  return Ticket(
    project: project,
    seq: seq,
    title: 'test ticket $seq',
    status: status,
    fields: {},
    createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
    updatedAt: DateTime.parse(updatedAtRaw),
    createdAtRaw: '2026-04-01T10:00:00+09:00',
    updatedAtRaw: updatedAtRaw,
  );
}

void main() {
  late Directory tmpDir;
  late TicketStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ticket_store_test_');
    store = TicketStore(tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('nextSeq', () {
    test('returns 1 for empty directory', () {
      expect(store.nextSeq('myproject'), equals(1));
    });

    test('returns max+1 after existing tickets', () {
      final dir = Directory('${tmpDir.path}/myproject');
      dir.createSync(recursive: true);
      final t1 = _makeTicket('myproject', 1, 'todo');
      final t3 = _makeTicket('myproject', 3, 'todo');
      File('${dir.path}/001.json')
          .writeAsStringSync(jsonEncode(t1.toJson()));
      File('${dir.path}/003.json')
          .writeAsStringSync(jsonEncode(t3.toJson()));

      expect(store.nextSeq('myproject'), equals(4));
    });
  });

  group('save', () {
    test('writes JSON file with correct name', () {
      final ticket = _makeTicket('proj', 5, 'todo');
      store.save(ticket);

      final file = File('${tmpDir.path}/proj/005.json');
      expect(file.existsSync(), isTrue);

      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(data['id'], equals('proj-005'));
      expect(data['seq'], equals(5));
      expect(data['status'], equals('todo'));
    });
  });

  group('load', () {
    test('reads ticket by seq number', () {
      final ticket = _makeTicket('proj', 2, 'in_progress');
      store.save(ticket);

      final loaded = store.load('proj', 2);
      expect(loaded.id, equals('proj-002'));
      expect(loaded.status, equals('in_progress'));
      expect(loaded.title, equals('test ticket 2'));
    });

    test('throws for non-existing ticket', () {
      expect(() => store.load('proj', 999), throwsException);
    });
  });

  group('listAll', () {
    test('returns all tickets for a project sorted by seq', () {
      store.save(_makeTicket('proj', 3, 'done'));
      store.save(_makeTicket('proj', 1, 'todo'));
      store.save(_makeTicket('proj', 2, 'in_progress'));

      final tickets = store.listAll('proj');
      expect(tickets.length, equals(3));
      expect(tickets[0].seq, equals(1));
      expect(tickets[1].seq, equals(2));
      expect(tickets[2].seq, equals(3));
    });

    test('returns empty list for non-existing project', () {
      expect(store.listAll('nonexistent'), isEmpty);
    });
  });

  group('listByStatus', () {
    test('filters tickets by status', () {
      store.save(_makeTicket('proj', 1, 'todo'));
      store.save(_makeTicket('proj', 2, 'done'));
      store.save(_makeTicket('proj', 3, 'todo'));

      final todos = store.listByStatus('proj', 'todo');
      expect(todos.length, equals(2));
      expect(todos.every((t) => t.status == 'todo'), isTrue);
    });
  });

  group('atomic write', () {
    test('file is written atomically via tmp + rename', () {
      final ticket = _makeTicket('proj', 1, 'todo');
      store.save(ticket);

      final file = File('${tmpDir.path}/proj/001.json');
      final tmpFile = File('${tmpDir.path}/proj/001.json.tmp');
      expect(file.existsSync(), isTrue);
      expect(tmpFile.existsSync(), isFalse);
    });
  });

  group('optimistic lock', () {
    test('save with stale updatedAt throws', () {
      final ticket = _makeTicket('proj', 1, 'todo',
          updatedAtRaw: '2026-04-02T10:00:00+09:00');
      store.save(ticket);

      final updatedTicket = _makeTicket('proj', 1, 'done',
          updatedAtRaw: '2026-04-03T10:00:00+09:00');

      expect(
        () => store.save(updatedTicket,
            expectedUpdatedAt: '2026-04-01T00:00:00+09:00'),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Optimistic lock'))),
      );
    });

    test('save with correct updatedAt succeeds', () {
      final ticket = _makeTicket('proj', 1, 'todo',
          updatedAtRaw: '2026-04-02T10:00:00+09:00');
      store.save(ticket);

      final updatedTicket = _makeTicket('proj', 1, 'done',
          updatedAtRaw: '2026-04-03T10:00:00+09:00');

      expect(
        () => store.save(updatedTicket,
            expectedUpdatedAt: '2026-04-02T10:00:00+09:00'),
        returnsNormally,
      );
    });
  });
}
