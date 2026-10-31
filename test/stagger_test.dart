import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/utils/stagger.dart';

/// Regression for the Oct 2026 user report: a flat £5/month projection
/// rendered each later month smaller (£5 → … → £4.38) because the staggered
/// animation never let later bars finish. The donut had the same bug.
void main() {
  test('every item is full when the animation completes', () {
    for (final count in [1, 2, 6, 12, 19]) {
      for (var i = 0; i < count; i++) {
        expect(
          staggeredProgress(1, i, count, stagger: 0.03),
          1.0,
          reason: 'item $i of $count',
        );
        expect(staggeredProgress(1, i, count), 1.0, reason: 'item $i of $count');
      }
    }
  });

  test('every item starts empty', () {
    for (var i = 0; i < 6; i++) {
      expect(staggeredProgress(0, i, 6), 0);
    }
  });

  test('later items trail earlier ones mid-animation', () {
    expect(
      staggeredProgress(0.3, 0, 6),
      greaterThan(staggeredProgress(0.3, 5, 6)),
    );
  });

  test('a stagger too long for the count still finishes', () {
    // 0.1 × 19 items would need more than the whole animation.
    expect(staggeredProgress(1, 18, 19), 1.0);
  });
}
