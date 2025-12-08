import 'dart:math';
import 'package:busmate_web/models/bus_location.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

/// Utility to simulate bus movements for testing
/// This helps test the real-time tracking without actual GPS devices
class BusSimulator {
  final Random _random = Random();
  
  /// Simulate a bus moving along a route
  /// This will update Firebase Realtime Database with mock GPS data
  /// If routePolyline is provided, follows the detailed road path; otherwise moves between stops
  Future<void> simulateBusMovement({
    required String schoolId,
    required String busId,
    required String driverId,
    required String driverName,
    required String routeId,
    required String routeName,
    required List<LatLng> routePoints,
    List<LatLng>? routePolyline, // Optional: OSRM polyline for road-following
    List<String>? stopNames, // Actual stop names from route schedule
    int totalStudents = 30,
    bool enableOlaMapsTesting = true, // Enable ETA calculation testing
  }) async {
    print('🚌 Starting simulation for Bus: $busId');
    
    // Use polyline for realistic road movement, otherwise use stop-to-stop
    final pathToFollow = (routePolyline != null && routePolyline.isNotEmpty) 
        ? routePolyline 
        : routePoints;
    
    if (routePolyline != null && routePolyline.isNotEmpty) {
      print('📍 Following ${pathToFollow.length} OSRM road points through ${routePoints.length} stops');
    } else {
      print('📍 Following ${pathToFollow.length} route stops (direct path)');
    }
    
    // Web browser does NOT call Ola Maps API!
    // Firebase Function handles ETA calculation when GPS updates arrive
    if (enableOlaMapsTesting && routePoints.length > 1) {
      print('\n✅ [ARCHITECTURE] Unified GPS System:');
      print('   📱 Phone GPS → Realtime DB → Firebase Function → Ola Maps API');
      print('   🔧 Hardware GPS → Realtime DB → Firebase Function → Ola Maps API');
      print('   🌐 Web Browser → Just READS Firestore (ETAs already calculated!)');
      print('');
      print('   💡 Web browser does NOT call Ola Maps directly!');
      print('   💡 Firebase Function calculates ETAs on segment completion');
      print('   💡 Web just displays the pre-calculated data');
      print('');
    }
    
    int currentPointIndex = 0;
    double progress = 0.0; // Progress between two points (0.0 to 1.0)
    int currentStopIndex = 0; // Track which stop we're near
    
    while (currentPointIndex < pathToFollow.length - 1) {
      // Get current and next point
      final currentPoint = pathToFollow[currentPointIndex];
      final nextPoint = pathToFollow[currentPointIndex + 1];
      
      // Interpolate position between points
      final lat = currentPoint.latitude + 
          (nextPoint.latitude - currentPoint.latitude) * progress;
      final lng = currentPoint.longitude + 
          (nextPoint.longitude - currentPoint.longitude) * progress;
      
      // If using polyline, find nearest actual stop for display
      if (routePolyline != null && routePolyline.isNotEmpty) {
        // Find the closest stop ahead of current position
        double minDistance = double.infinity;
        int closestStopAhead = currentStopIndex;
        
        for (int i = currentStopIndex; i < routePoints.length; i++) {
          final dx = routePoints[i].latitude - lat;
          final dy = routePoints[i].longitude - lng;
          final distance = (dx * dx + dy * dy); // Simple distance squared
          
          if (distance < minDistance) {
            minDistance = distance;
            closestStopAhead = i;
          }
        }
        
        // Only advance the stop index forward, never backward
        if (closestStopAhead > currentStopIndex) {
          currentStopIndex = closestStopAhead;
          print('🛑 Bus $busId passed stop ${currentStopIndex + 1}/${routePoints.length}');
        }
      } else {
        // Direct stop-to-stop: current point is the current stop
        currentStopIndex = currentPointIndex;
      }
      
      // Calculate heading (direction of travel)
      final heading = _calculateHeading(currentPoint, nextPoint);
      
      // Realistic speed between 15-45 km/h (slow school bus traffic)
      final speed = 15.0 + _random.nextDouble() * 30.0;
      
      // Random battery level (slowly decreasing)
      final batteryLevel = 100 - (currentPointIndex * 5) + _random.nextInt(5);
      
      // Determine status based on speed
      BusStatus status;
      if (speed < 5) {
        status = BusStatus.stopped;
      } else if (speed < 15) {
        status = BusStatus.idle;
      } else {
        status = BusStatus.moving;
      }
      
      // Get actual stop names or fallback to generic names
      String getCurrentStopName() {
        if (stopNames != null && stopNames.isNotEmpty && currentStopIndex < stopNames.length) {
          return stopNames[currentStopIndex];
        }
        return currentStopIndex < routePoints.length 
            ? 'Stop ${currentStopIndex + 1}' 
            : 'Final Stop';
      }
      
      String getNextStopName() {
        final nextIndex = currentStopIndex + 1;
        if (stopNames != null && stopNames.isNotEmpty && nextIndex < stopNames.length) {
          return stopNames[nextIndex];
        }
        return nextIndex < routePoints.length 
            ? 'Stop ${nextIndex + 1}' 
            : 'Final Stop';
      }
      
      // Create bus location
      final location = BusLocation(
        busId: busId,
        schoolId: schoolId,
        latitude: lat,
        longitude: lng,
        speed: speed,
        heading: heading,
        timestamp: DateTime.now(),
        driverId: driverId,
        driverName: driverName,
        routeId: routeId,
        routeName: routeName,
        status: status,
        batteryLevel: batteryLevel.clamp(10, 100),
        totalStudents: totalStudents,
        currentStop: getCurrentStopName(),
        nextStop: getNextStopName(),
        estimatedArrival: DateTime.now().add(
          Duration(minutes: (pathToFollow.length - currentPointIndex) * 2),
        ),
        isOnline: true,
      );
      
      // 🆕 CHECK PROXIMITY TO STOPS AND REMOVE PASSED STOPS
      // This matches the driver app behavior (200m threshold)
      try {
        final ref = FirebaseDatabase.instance.ref('bus_locations/$schoolId/$busId');
        final snapshot = await ref.get();
        
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          List<dynamic> remainingStops = data['remainingStops'] ?? [];
          
          if (remainingStops.isNotEmpty) {
            final busLocation = LatLng(lat, lng);
            final Distance distance = const Distance();
            const double stopProximityThreshold = 200.0; // 200 meters
            
            bool stopsRemoved = false;
            
            // Remove passed stops (check first stop only - sequential removal)
            if (remainingStops.isNotEmpty) {
              final firstStop = remainingStops.first;
              final stopLat = firstStop['latitude'] ?? 0.0;
              final stopLng = firstStop['longitude'] ?? 0.0;
              final stopName = firstStop['name'] ?? 'Unknown Stop';
              final stopLocation = LatLng(stopLat, stopLng);
              
              final distToStop = distance.as(LengthUnit.Meter, busLocation, stopLocation);
              
              if (distToStop <= stopProximityThreshold) {
                print('🎯 [WebSimulator] Bus reached stop: $stopName (${distToStop.toStringAsFixed(1)}m away)');
                remainingStops.removeAt(0); // Remove first stop
                stopsRemoved = true;
                print('✂️ [WebSimulator] Removed stop. Remaining: ${remainingStops.length} stops');
              }
            }
            
            // Update location and remaining stops
            await ref.update({
              ...location.toRealtimeDb(),
              if (stopsRemoved) 'remainingStops': remainingStops,
            });
          } else {
            // No remaining stops - just update location
            await ref.update(location.toRealtimeDb());
          }
        } else {
          // First write - just set the location
          await ref.update(location.toRealtimeDb());
        }
        
        print('📍 Updated: Bus $busId at (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}) - ${status.toString().split('.').last}');
      } catch (e) {
        print('❌ Error updating location: $e');
      }
      
      // Move progress forward - MUCH slower for realistic simulation
      // 2% progress every 30 seconds = 50 updates to complete one segment
      // This makes a 1km segment take ~25 minutes at normal speed
      progress += 0.02; // Small increment for very slow, realistic movement
      
      if (progress >= 1.0) {
        progress = 0.0;
        currentPointIndex++;
        if (routePolyline == null || routePolyline.isEmpty) {
          // Only print for direct stop-to-stop
          print('🛑 Bus $busId reached stop ${currentStopIndex + 1}/${routePoints.length}');
        }
      }
      
      // Wait before next update (simulate real-time GPS updates every 30 seconds)
      // This matches the driver app's background location update frequency
      await Future.delayed(const Duration(seconds: 30));
    }
    
    // Mark bus as inactive when simulation completes
    try {
      final ref = FirebaseDatabase.instance.ref('bus_locations/$schoolId/$busId');
      await ref.update({
        'isActive': false,
        'isOnline': false,
        'status': 'completed',
      });
      print('✅ Simulation complete for Bus: $busId - Route completed, bus set to inactive');
    } catch (e) {
      print('❌ Error marking bus inactive: $e');
    }
  }
  
  /// Calculate heading (bearing) between two points in degrees
  double _calculateHeading(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;
    
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    
    final heading = atan2(y, x) * 180 / pi;
    
    return (heading + 360) % 360; // Normalize to 0-360
  }
  
  /// Generate a simple route for testing (circular path)
  static List<LatLng> generateTestRoute({
    required LatLng center,
    int stopCount = 10,
    double radiusKm = 5.0,
  }) {
    final points = <LatLng>[];
    final random = Random();
    
    for (int i = 0; i < stopCount; i++) {
      final angle = (2 * pi * i) / stopCount;
      
      // Add some randomness to make it more realistic
      final radius = radiusKm * (0.7 + random.nextDouble() * 0.6);
      
      final lat = center.latitude + (radius / 111.32) * cos(angle);
      final lng = center.longitude + 
          (radius / (111.32 * cos(center.latitude * pi / 180))) * sin(angle);
      
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }
  
  /// Set bus offline status
  static Future<void> setBusOffline(String schoolId, String busId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('bus_locations/$schoolId/$busId');
      await ref.update({'isOnline': false, 'status': 'offline'});
      print('🔴 Bus $busId set to offline');
    } catch (e) {
      print('❌ Error setting bus offline: $e');
    }
  }
  
  /// Set bus online status
  static Future<void> setBusOnline(String schoolId, String busId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('bus_locations/$schoolId/$busId');
      await ref.update({'isOnline': true});
      print('🟢 Bus $busId set to online');
    } catch (e) {
      print('❌ Error setting bus online: $e');
    }
  }
}

/// Example usage:
/// 
/// ```dart
/// final simulator = BusSimulator();
/// 
/// // Generate a test route
/// final route = BusSimulator.generateTestRoute(
///   center: LatLng(11.0168, 76.9558), // Coimbatore
///   stopCount: 15,
///   radiusKm: 5.0,
/// );
/// 
/// // Simulate bus movement
/// simulator.simulateBusMovement(
///   schoolId: 'school123',
///   busId: 'bus001',
///   driverId: 'driver001',
///   driverName: 'John Doe',
///   routeId: 'route001',
///   routeName: 'Route A - Morning',
///   routePoints: route,
///   totalStudents: 35,
/// );
/// ```
