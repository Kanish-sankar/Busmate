import 'package:flutter_test/flutter_test.dart';
import 'package:busmate/services/ola_distance_matrix_service.dart';
import 'package:busmate/meta/model/bus_model.dart';

void main() {
  group('Ola Maps ETA System Tests', () {
    
    test('Segment division - 8 stops should create 4 segments', () {
      print('\n📊 TEST: 8 stops segmentation');
      final segments = divideIntoSegments(8);
      
      print('Created ${segments.length} segments:');
      for (var seg in segments) {
        print('  Segment ${seg.number}: ${seg.stopCount} stops (${seg.startStopIndex}-${seg.endStopIndex})');
      }
      
      expect(segments.length, 4);
      expect(segments[0].stopCount, 2);
      expect(segments[1].stopCount, 2);
      expect(segments[2].stopCount, 2);
      expect(segments[3].stopCount, 2);
      expect(segments[0].status, 'in_progress');
      expect(segments[1].status, 'pending');
    });
    
    test('Segment division - 13 stops should create 4 segments', () {
      print('\n📊 TEST: 13 stops segmentation');
      final segments = divideIntoSegments(13);
      
      print('Created ${segments.length} segments:');
      for (var seg in segments) {
        print('  Segment ${seg.number}: ${seg.stopCount} stops (${seg.startStopIndex}-${seg.endStopIndex})');
      }
      
      expect(segments.length, 4);
      expect(segments[0].stopCount, 4); // 13 ÷ 4 = 3.25, first gets remainder
      expect(segments[1].stopCount, 3);
      expect(segments[2].stopCount, 3);
      expect(segments[3].stopCount, 3);
    });
    
    test('Segment division - 25 stops should create 5 segments', () {
      print('\n📊 TEST: 25 stops segmentation');
      final segments = divideIntoSegments(25);
      
      print('Created ${segments.length} segments:');
      for (var seg in segments) {
        print('  Segment ${seg.number}: ${seg.stopCount} stops (${seg.startStopIndex}-${seg.endStopIndex})');
      }
      
      expect(segments.length, 5); // 25 stops ÷ 5 = 5 stops per segment
      expect(segments[0].stopCount, 5);
      expect(segments[1].stopCount, 5);
      expect(segments[2].stopCount, 5);
      expect(segments[3].stopCount, 5);
      expect(segments[4].stopCount, 5);
    });
    
    test('Segment division - 20 stops should create 4 segments', () {
      print('\n📊 TEST: 20 stops segmentation (boundary case)');
      final segments = divideIntoSegments(20);
      
      print('Created ${segments.length} segments:');
      for (var seg in segments) {
        print('  Segment ${seg.number}: ${seg.stopCount} stops (${seg.startStopIndex}-${seg.endStopIndex})');
      }
      
      expect(segments.length, 4);
      expect(segments[0].stopCount, 5);
      expect(segments[1].stopCount, 5);
      expect(segments[2].stopCount, 5);
      expect(segments[3].stopCount, 5);
    });
    
    test('Segment division - 21 stops should create 5 segments', () {
      print('\n📊 TEST: 21 stops segmentation (just above boundary)');
      final segments = divideIntoSegments(21);
      
      print('Created ${segments.length} segments:');
      for (var seg in segments) {
        print('  Segment ${seg.number}: ${seg.stopCount} stops (${seg.startStopIndex}-${seg.endStopIndex})');
      }
      
      expect(segments.length, 5); // ceil(21 / 5) = 5
      expect(segments[0].stopCount, 5); // 21 % 5 = 1 extra, distributed
      expect(segments[1].stopCount, 4);
      expect(segments[2].stopCount, 4);
      expect(segments[3].stopCount, 4);
      expect(segments[4].stopCount, 4);
    });
    
    test('Segment JSON serialization', () {
      print('\n📊 TEST: Segment serialization');
      
      final segment = BusSegment(
        number: 1,
        startStopIndex: 0,
        endStopIndex: 4,
        stopIndices: [0, 1, 2, 3, 4],
        status: 'in_progress',
      );
      
      final json = segment.toJson();
      print('Serialized: $json');
      
      final deserialized = BusSegment.fromJson(json);
      print('Deserialized: segment ${deserialized.number}, status: ${deserialized.status}');
      
      expect(deserialized.number, 1);
      expect(deserialized.startStopIndex, 0);
      expect(deserialized.endStopIndex, 4);
      expect(deserialized.status, 'in_progress');
      expect(deserialized.stopCount, 5);
    });
    
    test('Should recalculate ETAs - segment-based', () {
      print('\n📊 TEST: ETA recalculation logic - segment-based');
      
      // Just completed a segment
      final shouldRecalc1 = OlaDistanceMatrixService.shouldRecalculateETAs(
        totalStops: 20,
        stopsPassedCount: 5, // Just completed segment 1
        lastRecalculationAt: 0,
        lastRecalculationTime: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      print('After completing segment: $shouldRecalc1');
      expect(shouldRecalc1, true);
      
      // No segment completion
      final shouldRecalc2 = OlaDistanceMatrixService.shouldRecalculateETAs(
        totalStops: 20,
        stopsPassedCount: 3, // Mid-segment
        lastRecalculationAt: 0,
        lastRecalculationTime: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      print('Mid-segment: $shouldRecalc2');
      expect(shouldRecalc2, false);
      
      // Old calculation (>10 min)
      final shouldRecalc3 = OlaDistanceMatrixService.shouldRecalculateETAs(
        totalStops: 20,
        stopsPassedCount: 3,
        lastRecalculationAt: 3,
        lastRecalculationTime: DateTime.now().subtract(const Duration(minutes: 11)),
      );
      print('Old calculation (>10 min): $shouldRecalc3');
      expect(shouldRecalc3, true);
    });
    
    // NOTE: The following test requires internet and valid API key
    // Uncomment to test real API calls
    /*
    test('Ola Maps API call - real test', () async {
      print('\n📊 TEST: Real Ola Maps API call');
      
      final currentLocation = LatLng(12.9716, 77.5946); // Bangalore
      final stops = [
        LatLng(12.9800, 77.6000),
        LatLng(12.9850, 77.6050),
        LatLng(12.9900, 77.6100),
      ];
      
      print('Testing 3 stops from Bangalore...');
      
      try {
        final etaResults = await OlaDistanceMatrixService.calculateAllStopETAs(
          currentLocation: currentLocation,
          stops: stops,
          waypointsPerStop: null,
        );
        
        print('✅ Received ${etaResults.length} ETAs');
        etaResults.forEach((index, eta) {
          print('  Stop ${index + 1}: ${eta.formattedETA} (${eta.formattedDistance})');
        });
        
        expect(etaResults.length, 3);
        expect(etaResults[0]!.distanceMeters, greaterThan(0));
        expect(etaResults[0]!.durationSeconds, greaterThan(0));
        
      } catch (e) {
        print('❌ API Error: $e');
        fail('API call failed: $e');
      }
    }, timeout: Timeout(Duration(seconds: 30)));
    */
  });
}
