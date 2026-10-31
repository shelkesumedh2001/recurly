import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

/// Material 3 window size classes, by available width.
///
/// Compact = phones and folded foldables. Medium = unfolded foldables in
/// portrait, small tablets. Expanded = unfolded foldables in landscape,
/// tablets.
enum WindowClass { compact, medium, expanded }

WindowClass windowClassFor(double width) {
  if (width < 600) return WindowClass.compact;
  if (width < 840) return WindowClass.medium;
  return WindowClass.expanded;
}

WindowClass windowClassOf(BuildContext context) =>
    windowClassFor(MediaQuery.sizeOf(context).width);

/// Widest a single column of text and cards should get. Past this, lines
/// get hard to read and cards look stretched.
const double kReadableWidth = 640;

/// Content width at which a screen switches to a two-column / two-pane
/// layout. Below it, a single column (capped at [kReadableWidth]) reads
/// better than two cramped ones.
const double kTwoPaneMinWidth = 720;

/// Caps [child]'s width at [maxWidth], aligned to the start edge so content
/// lines up under the screen title. A no-op on phones.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = kReadableWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A vertical fold or hinge crossing a region that starts [regionLeft]
/// logical pixels from the screen's left edge and is [regionWidth] wide.
/// Returns its left edge and width within the region, or null.
///
/// Book-style foldables report their crease through
/// `MediaQuery.displayFeatures`. Content split across it is hard to read
/// (and hidden, on hinged devices), so panes should meet at the fold.
({double left, double width})? verticalFoldIn(
  List<DisplayFeature> features, {
  required double regionLeft,
  required double regionWidth,
}) {
  for (final f in features) {
    if (f.type != DisplayFeatureType.fold &&
        f.type != DisplayFeatureType.hinge) {
      continue;
    }
    final b = f.bounds;
    if (b.height <= b.width) continue; // horizontal: tabletop posture
    final left = b.left - regionLeft;
    if (left <= 0 || left >= regionWidth) continue;
    return (left: left, width: b.width);
  }
  return null;
}

/// Two side-by-side panes for wide windows.
///
/// When a vertical fold crosses the panes, they meet at the fold (each pane
/// keeps clear of it). Otherwise [start] gets [startFraction] of the width,
/// clamped to [minStartWidth]..[maxStartWidth], and [end] takes the rest.
///
/// Assumes the panes are flush with the screen's right edge (true beside a
/// navigation rail), to place the fold in local coordinates.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.start,
    required this.end,
    this.startFraction = 0.42,
    this.minStartWidth = 320,
    this.maxStartWidth = 440,
    this.minPaneWidth = 280,
  });

  final Widget start;
  final Widget end;
  final double startFraction;
  final double minStartWidth;
  final double maxStartWidth;

  /// A fold that would leave either pane narrower than this is ignored.
  final double minPaneWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final features = MediaQuery.displayFeaturesOf(context);
    final divider = Theme.of(context).colorScheme.outline.withValues(alpha: 0.1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fold = verticalFoldIn(
          features,
          regionLeft: screenWidth - width,
          regionWidth: width,
        );

        double startWidth;
        double gap;
        if (fold != null &&
            fold.left >= minPaneWidth &&
            width - fold.left - fold.width >= minPaneWidth) {
          startWidth = fold.left;
          gap = fold.width;
        } else {
          startWidth =
              (width * startFraction).clamp(minStartWidth, maxStartWidth);
          gap = 0;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: startWidth, child: start),
            if (gap > 0)
              SizedBox(width: gap)
            else
              VerticalDivider(width: 1, thickness: 1, color: divider),
            Expanded(child: end),
          ],
        );
      },
    );
  }
}
