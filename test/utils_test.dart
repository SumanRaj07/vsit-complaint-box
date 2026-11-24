import 'package:flutter_test/flutter_test.dart';
import 'package:vsit_complaint_box/core/utils.dart';

void main() {
  group('Tracking IDs', () {
    test('first complaint of the year is VSIT-YYYY-0001', () {
      expect(nextTrackingId(2026, []), 'VSIT-2026-0001');
    });

    test('increments from the highest existing number', () {
      expect(
        nextTrackingId(2026, ['VSIT-2026-0001', 'VSIT-2026-0007']),
        'VSIT-2026-0008',
      );
    });

    test('numbers from another year are ignored', () {
      expect(
        nextTrackingId(2026, ['VSIT-2025-0042']),
        'VSIT-2026-0001',
      );
    });
  });

  group('Anonymous PIN', () {
    test('generated PIN is 6 digits', () {
      final pin = generatePin();
      expect(pin.length, 6);
      expect(int.tryParse(pin), isNotNull);
    });

    test('hash and verify round-trip', () {
      const pin = '123456';
      final hash = hashPin(pin);
      expect(verifyPin(pin, hash), isTrue);
      expect(verifyPin('654321', hash), isFalse);
    });

    test('same PIN always hashes the same way', () {
      expect(hashPin('000001'), hashPin('000001'));
    });
  });

  group('Duplicate detection', () {
    test('similar text in the same category and department matches', () {
      expect(
        isPotentialDuplicate(
          title: 'Projector not working in Lab 3',
          description: 'The projector in computer lab 3 has been broken for two weeks',
          category: 'Computer Laboratory',
          departmentId: 'dept-it',
          other: {
            'title': 'Projector not working in Lab 3',
            'description': 'Projector in computer lab 3 broken for two weeks',
            'category': 'Computer Laboratory',
            'department_id': 'dept-it',
          },
        ),
        isTrue,
      );
    });

    test('different category never matches', () {
      expect(
        isPotentialDuplicate(
          title: 'Projector not working in Lab 3',
          description: 'The projector in computer lab 3 has been broken',
          category: 'Library',
          departmentId: 'dept-it',
          other: {
            'title': 'Projector broken in Lab 3',
            'description': 'Projector in lab 3 not working',
            'category': 'Computer Laboratory',
            'department_id': 'dept-it',
          },
        ),
        isFalse,
      );
    });

    test('unrelated text does not match', () {
      expect(
        textSimilarity('canteen food is stale and overpriced',
            'wifi disconnects every ten minutes'),
        lessThan(0.35),
      );
    });
  });

  group('SLA', () {
    const sla = {'critical': 24, 'high': 72, 'medium': 120, 'low': 240};

    test('fresh high-priority complaint is not breached', () {
      final created = DateTime(2026, 11, 20, 10);
      expect(
        isSlaBreached(
          createdAt: created,
          priority: 'high',
          slaHours: sla,
          now: DateTime(2026, 11, 21, 10),
        ),
        isFalse,
      );
    });

    test('critical complaint older than 24h is breached', () {
      final created = DateTime(2026, 11, 20, 10);
      expect(
        isSlaBreached(
          createdAt: created,
          priority: 'critical',
          slaHours: sla,
          now: DateTime(2026, 11, 21, 11),
        ),
        isTrue,
      );
    });
  });

  group('Status machine', () {
    test('submitted can go to acknowledged but not to resolved', () {
      expect(canTransition('submitted', 'acknowledged'), isTrue);
      expect(canTransition('submitted', 'resolved'), isFalse);
    });

    test('closed is a final state', () {
      expect(canTransition('closed', 'reopened'), isFalse);
    });

    test('reopen allowed within 7 days of resolution', () {
      final resolvedAt = DateTime.now().subtract(const Duration(days: 3));
      expect(canReopen('resolved', resolvedAt), isTrue);
      final old = DateTime.now().subtract(const Duration(days: 10));
      expect(canReopen('resolved', old), isFalse);
      expect(canReopen('submitted', null), isFalse);
    });
  });
}
