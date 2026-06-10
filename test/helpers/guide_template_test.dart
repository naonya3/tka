import 'package:test/test.dart';
import 'package:tka/helpers/guide_template.dart';
import 'package:tka/models/ticket.dart';

Ticket _ticket() => Ticket(
      project: 'shop',
      seq: 7,
      title: 'Buy milk',
      status: 'todo',
      fields: {},
      createdAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      updatedAt: DateTime.parse('2026-04-01T10:00:00+09:00'),
      createdAtRaw: '2026-04-01T10:00:00+09:00',
      updatedAtRaw: '2026-04-01T10:00:00+09:00',
    );

void main() {
  group('expandGuide', () {
    test('expands {{id}}, {{project}} and {{seq}}', () {
      expect(
        expandGuide(
            'Claim with: tka transition {{id}} --to running ({{project}} #{{seq}})',
            _ticket()),
        equals('Claim with: tka transition shop-007 --to running (shop #7)'),
      );
    });

    test('expands repeated placeholders and leaves unknown ones alone', () {
      expect(
        expandGuide('{{id}} {{id}} {{title}}', _ticket()),
        equals('shop-007 shop-007 {{title}}'),
      );
    });
  });
}
