import 'package:flutter_test/flutter_test.dart';
import 'package:traveltrack/src/models/map_rotation.dart';

void main() {
  group('northUpRotationTarget', () {
    test('keeps a map already facing north unchanged', () {
      expect(northUpRotationTarget(0), 0);
      expect(northUpRotationTarget(360), 360);
    });

    test('turns back the short way for small clockwise rotations', () {
      expect(northUpRotationTarget(30), 0);
      expect(northUpRotationTarget(180), 0);
    });

    test('turns forward to the next full turn when it is closer', () {
      expect(northUpRotationTarget(350), 360);
      expect(northUpRotationTarget(190), 360);
    });

    test('handles negative rotations', () {
      expect(northUpRotationTarget(-10), 0);
      expect(northUpRotationTarget(-170), 0);
      expect(northUpRotationTarget(-190), -360);
    });

    test('handles rotations accumulated over several turns', () {
      expect(northUpRotationTarget(725), 720);
      expect(northUpRotationTarget(1070), 1080);
    });
  });
}
