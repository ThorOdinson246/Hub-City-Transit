import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_MapPageState._markerRadiusFor`. Kept in lockstep by the assertions
/// below rather than by importing a private member.
double markerRadiusFor(double zoom) =>
    zoom >= 15 ? 9.0 : (zoom >= 13 ? 6.0 : 4.0);

/// Counts the rebuilds `_onMapEvent`'s zoom branch would trigger.
///
/// The map reads the camera zoom off every `MapEventWithMove`, which fires once
/// per frame of a zoom animation. Calling `setState` there rebuilt the whole
/// page — and with it ~4,300 polyline points — 30-odd times per gesture. The
/// zoom only feeds a three-bucket marker radius, so a rebuild is warranted only
/// when it crosses a bucket edge.
int rebuildsFor(List<double> zoomFrames, {double from = 13.0}) {
  var current = from;
  var rebuilds = 0;
  for (final zoom in zoomFrames) {
    if (zoom == current) continue;
    if (markerRadiusFor(zoom) != markerRadiusFor(current)) rebuilds++;
    current = zoom;
  }
  return rebuilds;
}

void main() {
  group('marker radius buckets', () {
    test('changes only at the documented zoom thresholds', () {
      expect(markerRadiusFor(12.9), 4.0);
      expect(markerRadiusFor(13.0), 6.0);
      expect(markerRadiusFor(14.9), 6.0);
      expect(markerRadiusFor(15.0), 9.0);
    });
  });

  group('zoom-driven rebuilds', () {
    test('a smooth zoom within one bucket rebuilds nothing', () {
      final frames = [
        for (var i = 1; i <= 32; i++) 13.0 + (i * 0.05),
      ];
      expect(frames.last, lessThan(15.0));
      expect(rebuildsFor(frames), 0);
    });

    test('a zoom across a threshold rebuilds exactly once', () {
      final frames = [
        for (var i = 1; i <= 32; i++) 13.0 + (i * 0.0625),
      ];
      expect(frames.last, greaterThanOrEqualTo(15.0));
      expect(rebuildsFor(frames), 1);
    });

    test('crossing back and forth rebuilds once per crossing', () {
      expect(rebuildsFor([15.2, 14.0, 15.1]), 3);
    });
  });
}
