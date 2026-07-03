import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/utils/money.dart';

void main() {
  group('roundMoney (bug #5 — floating-point money drift)', () {
    test('removes accumulated drift to whole cents', () {
      expect(roundMoney(4.995000000001), 5.0);
      expect(roundMoney(29.999999999), 30.0);
      expect(roundMoney(0.1 + 0.2), 0.3); // 0.30000000000000004 → 0.3
    });

    test('cleans split-percentage math', () {
      // 9.99 split 50/50 → 4.995 → 5.00
      expect(roundMoney(9.99 * 0.5), 5.0);
    });

    test('leaves already-clean values unchanged', () {
      expect(roundMoney(9.99), 9.99);
      expect(roundMoney(0), 0);
      expect(roundMoney(100), 100);
    });

    test('a budget-boundary comparison is no longer flipped by drift', () {
      const budget = 30.0;
      const driftedSpend = 10.0 + 10.0 + 9.999999999; // ~29.999999999
      // Raw double would read under; that is fine here, but the symmetric
      // over-budget case (30.0000001) must not read as over once rounded.
      expect(roundMoney(driftedSpend) <= budget, isTrue);
      expect(roundMoney(30.00000001) > budget, isFalse);
    });
  });
}
