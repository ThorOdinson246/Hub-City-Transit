import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubcity_transit_flutter/src/core/layout/responsive.dart';

void main() {
  group('Breakpoints', () {
    test('classifies widths into Material 3 window size classes', () {
      expect(Breakpoints.fromWidth(390), WindowSize.compact);
      expect(Breakpoints.fromWidth(599.9), WindowSize.compact);
      expect(Breakpoints.fromWidth(600), WindowSize.medium);
      expect(Breakpoints.fromWidth(839.9), WindowSize.medium);
      expect(Breakpoints.fromWidth(840), WindowSize.expanded);
      expect(Breakpoints.fromWidth(1440), WindowSize.expanded);
    });

    test('only a phone-width window keeps the bottom navigation bar', () {
      expect(Breakpoints.fromWidth(390).prefersRail, isFalse);
      expect(Breakpoints.fromWidth(840).prefersRail, isTrue);
    });
  });

  group('ContentPane', () {
    /// Width actually offered to the pane's child at a given viewport width.
    Future<double> maxWidthAt(WidgetTester tester, double width) async {
      late double captured;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          // pumpWidget hands the root tight surface constraints, which a bare
          // SizedBox cannot shrink below. Center loosens them first.
          child: Center(
            child: SizedBox(
            width: width,
            height: 600,
            child: ContentPane(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  captured = constraints.maxWidth;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          ),
        ),
      );
      return captured;
    }

    testWidgets('caps content at a readable width on a desktop window',
        (tester) async {
      expect(await maxWidthAt(tester, 1440), Breakpoints.readableContent);
    });

    testWidgets('leaves a phone-width window unconstrained', (tester) async {
      expect(await maxWidthAt(tester, 390), 390);
    });
  });
}
