import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app_5/location_utils.dart';

void main() {
  group('calculateDistance', () {
    test('should return non-zero distance for different coordinates', () {
      // Test distance from (0, 0) to (0.001, 0.001)
      final distance = calculateDistance(0.0, 0.0, 0.001, 0.001);
      expect(distance, greaterThan(0.0));
    });

    test('should return zero distance for identical coordinates', () {
      final distance = calculateDistance(45.0, -73.0, 45.0, -73.0);
      expect(distance, closeTo(0.0, 0.001));
    });

    test('should calculate reasonable distance between known cities', () {
      // Approximate distance between New York (40.7128, -74.0060) and Los Angeles (34.0522, -118.2437)
      // Should be around 3944 km
      final distance = calculateDistance(40.7128, -74.0060, 34.0522, -118.2437);
      expect(distance, greaterThan(3000));
      expect(distance, lessThan(5000));
    });

    test('should handle negative coordinates', () {
      final distance = calculateDistance(-45.0, -73.0, -45.001, -73.001);
      expect(distance, greaterThan(0.0));
    });
  });
}


