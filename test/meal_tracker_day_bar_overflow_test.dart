// Tests that the Meal Tracker day/date navigator bar does not overflow at
// various phone widths and text-scale factors.
//
// The root cause was a fixed 72 px SliverPersistentHeaderDelegate extent that
// could not accommodate scaled text on Vivo/custom-font devices.
// The fix computes the extent dynamically via _DayNavigatorDelegate.computeExtent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal standalone reproduction of the day-navigator content.
// We can't instantiate _DayNavigatorDelegate directly (private), so we build
// the equivalent Column in a constrained box and assert no overflow.
// ---------------------------------------------------------------------------

Widget _dayBarContent({
  required double textScale,
  required double availableHeight,
  String weekday = 'Wednesday',
  String dateLine = 'Aug 19, 2026',
  bool isToday = true,
}) {
  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
    ),
    child: SizedBox(
      height: availableHeight,
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  dateLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

/// Compute the extent using the same formula as _DayNavigatorDelegate.computeExtent.
double _computeExtent(double textScale) {
  final contentHeight = (16 * textScale) + 2 + (13 * textScale);
  const chrome = 12.0 + 8.0;
  return (contentHeight + chrome).clamp(64.0, 120.0);
}

void main() {
  group('_DayNavigatorDelegate extent formula', () {
    test('scale 1.0 → >= 64', () {
      expect(_computeExtent(1.0), greaterThanOrEqualTo(64.0));
    });

    test('scale 1.0 → <= 72 (roughly same as before)', () {
      // At 1.0 the result should be ~49 (content) + 20 (chrome) = 69 px,
      // clamped to 64 minimum. Must stay close to original 72 design.
      expect(_computeExtent(1.0), lessThanOrEqualTo(72.0));
    });

    test('scale 1.3 → > 72 (was the overflow point)', () {
      // The old 72-px hard cap caused overflow at >=1.3.
      // Now the extent must grow beyond 72.
      expect(_computeExtent(1.3), greaterThan(72.0));
    });

    test('scale 1.5 → grows proportionally', () {
      final e13 = _computeExtent(1.3);
      final e15 = _computeExtent(1.5);
      expect(e15, greaterThan(e13));
    });

    test('scale 2.0 → clamped to 120', () {
      expect(_computeExtent(2.0), equals(120.0));
    });

    test('scale 1.0 → content fits in extent', () {
      final extent = _computeExtent(1.0);
      final contentHeight = (16 * 1.0 * 1.15) + 2 + (13 * 1.0 * 1.15);
      // With 12 dp outer padding the available height is extent - 12.
      expect(extent - 12, greaterThanOrEqualTo(contentHeight));
    });

    test('scale 1.3 → content fits in extent', () {
      final scale = 1.3;
      final extent = _computeExtent(scale);
      final contentHeight = (16 * scale * 1.15) + 2 + (13 * scale * 1.15);
      expect(extent - 12, greaterThanOrEqualTo(contentHeight));
    });
  });

  // -------------------------------------------------------------------------
  // Widget-level overflow tests: build the day-bar Column inside a SizedBox
  // matching the computed extent and assert Flutter reports no overflow.
  // -------------------------------------------------------------------------
  group('Day-bar widget overflow — various widths & text scales', () {
    const widths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];
    const scales = [1.0, 1.15, 1.3, 1.5];

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets(
          'no overflow at width=$width scale=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width * 3, 800 * 3);
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);

            final extent = _computeExtent(scale);

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: _dayBarContent(
                      textScale: scale,
                      availableHeight: extent,
                    ),
                  ),
                ),
              ),
            );

            // No RenderFlex overflow exception should be thrown.
            expect(tester.takeException(), isNull);

            // Weekday text must be visible.
            expect(find.text('Wednesday'), findsOneWidget);
            // Date must be visible.
            expect(find.text('Aug 19, 2026'), findsOneWidget);
            // Today badge.
            expect(find.text('Today'), findsOneWidget);
          },
        );
      }
    }

    testWidgets('long weekday name Wednesday does not overflow at 320dp 1.5x',
        (tester) async {
      tester.view.physicalSize = const Size(960, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final extent = _computeExtent(1.5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _dayBarContent(
                textScale: 1.5,
                availableHeight: extent,
                weekday: 'Wednesday',
                dateLine: 'Aug 19, 2026',
                isToday: true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('non-today date (no badge) does not overflow at 320dp 1.3x',
        (tester) async {
      tester.view.physicalSize = const Size(960, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final extent = _computeExtent(1.3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _dayBarContent(
                textScale: 1.3,
                availableHeight: extent,
                weekday: 'Saturday',
                dateLine: 'Aug 10, 2026',
                isToday: false,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Today'), findsNothing);
    });
  });
}
