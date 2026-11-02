import 'package:flutter/animation.dart';

/// Eased progress (0..1) for item [index] of [count] in a staggered
/// entrance, at overall animation progress [t] (0..1).
///
/// Each item starts [stagger] after the previous one, and EVERY item
/// reaches exactly 1.0 when [t] reaches 1.0. Chart marks drawn with this
/// therefore always settle at their true value.
///
/// The naive form `(t - index * stagger).clamp(0, 1)` never lets later
/// items finish: a flat £5/month projection rendered as £5.00 down to
/// £4.38, and donut slices settled at the wrong proportions (user report,
/// Oct 2026).
double staggeredProgress(
  double t,
  int index,
  int count, {
  double stagger = 0.1,
}) {
  final span = 1.0 - stagger * (count - 1);
  final double local;
  if (span <= 0) {
    local = t;
  } else {
    local = (t - index * stagger) / span;
  }
  return Curves.easeOutCubic.transform(local.clamp(0.0, 1.0));
}
