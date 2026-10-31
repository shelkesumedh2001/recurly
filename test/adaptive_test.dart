import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/utils/adaptive.dart';

DisplayFeature _fold(Rect bounds, {DisplayFeatureType type = DisplayFeatureType.fold}) =>
    DisplayFeature(bounds: bounds, type: type, state: DisplayFeatureState.postureHalfOpened);

void main() {
  test('window classes follow the Material 3 breakpoints', () {
    expect(windowClassFor(411), WindowClass.compact); // phone / folded
    expect(windowClassFor(599), WindowClass.compact);
    expect(windowClassFor(600), WindowClass.medium);
    expect(windowClassFor(839), WindowClass.medium);
    expect(windowClassFor(840), WindowClass.expanded); // unfolded, landscape
  });

  group('verticalFoldIn', () {
    test('finds a vertical fold and maps it into the region', () {
      final fold = verticalFoldIn(
        [_fold(const Rect.fromLTWH(420, 0, 0, 900))],
        regionLeft: 80, // beside a navigation rail
        regionWidth: 760,
      );
      expect(fold, (left: 340.0, width: 0.0));
    });

    test('keeps a hinge width (Surface Duo style)', () {
      final fold = verticalFoldIn(
        [
          _fold(
            const Rect.fromLTWH(540, 0, 34, 720),
            type: DisplayFeatureType.hinge,
          ),
        ],
        regionLeft: 0,
        regionWidth: 1114,
      );
      expect(fold, (left: 540.0, width: 34.0));
    });

    test('ignores horizontal folds (tabletop) and cutouts', () {
      expect(
        verticalFoldIn(
          [
            _fold(const Rect.fromLTWH(0, 450, 840, 0)),
            const DisplayFeature(
              bounds: Rect.fromLTWH(400, 0, 40, 30),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
          regionLeft: 0,
          regionWidth: 840,
        ),
        isNull,
      );
    });

    test('ignores a fold outside the region', () {
      expect(
        verticalFoldIn(
          [_fold(const Rect.fromLTWH(60, 0, 0, 900))],
          regionLeft: 80,
          regionWidth: 760,
        ),
        isNull,
      );
    });
  });

  group('TwoPane', () {
    Future<(Rect, Rect)> layout(
      WidgetTester tester, {
      required Size screen,
      List<DisplayFeature> features = const [],
    }) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = features;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TwoPane(
              start: SizedBox.expand(key: Key('start')),
              end: SizedBox.expand(key: Key('end')),
            ),
          ),
        ),
      );
      return (
        tester.getRect(find.byKey(const Key('start'))),
        tester.getRect(find.byKey(const Key('end'))),
      );
    }

    testWidgets('without a fold, start takes a clamped share', (tester) async {
      final (start, end) = await layout(tester, screen: const Size(900, 800));
      expect(start.width, closeTo(900 * 0.42, 0.01));
      expect(end.left, greaterThan(start.right));
      expect(end.right, 900);
    });

    testWidgets('panes meet at a vertical fold', (tester) async {
      final (start, end) = await layout(
        tester,
        screen: const Size(1000, 800),
        features: [_fold(const Rect.fromLTWH(500, 0, 0, 800))],
      );
      expect(start.right, 500);
      expect(end.left, 501); // the 1px divider sits on the crease
    });

    testWidgets('nothing sits under a hinge', (tester) async {
      final (start, end) = await layout(
        tester,
        screen: const Size(1114, 720),
        features: [
          _fold(
            const Rect.fromLTWH(540, 0, 34, 720),
            type: DisplayFeatureType.hinge,
          ),
        ],
      );
      expect(start.right, 540);
      expect(end.left, 574);
    });

    testWidgets('a fold leaving a pane too narrow is ignored', (tester) async {
      final (start, _) = await layout(
        tester,
        screen: const Size(900, 800),
        features: [_fold(const Rect.fromLTWH(200, 0, 0, 800))],
      );
      expect(start.width, closeTo(900 * 0.42, 0.01));
    });
  });

  testWidgets('ReadableWidth caps wide content, aligned to the start', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadableWidth(child: SizedBox.expand(key: Key('c'))),
      ),
    );
    final r = tester.getRect(find.byKey(const Key('c')));
    expect(r.width, kReadableWidth);
    expect(r.left, 0);
  });
}
