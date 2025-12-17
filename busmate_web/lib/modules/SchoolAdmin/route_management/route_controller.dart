// route_management_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:busmate_web/services/osrm_service.dart';

class Stop {
  final String name;
  final LatLng location;
  final List<LatLng> waypointsToNext; // Waypoints between this stop and the next
  final bool isWaypoint; // True if this is just a route waypoint, not an actual bus stop

  Stop({
    required this.name,
    required this.location,
    this.waypointsToNext = const [],
    this.isWaypoint = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'waypointsToNext': waypointsToNext
          .map((wp) => {'latitude': wp.latitude, 'longitude': wp.longitude})
          .toList(),
      'isWaypoint': isWaypoint,
    };
  }

  factory Stop.fromMap(Map<String, dynamic> map) {
    final locationMap = map['location'] as Map<String, dynamic>;
    final waypointsList = (map['waypointsToNext'] as List?)
            ?.map((wp) => LatLng(wp['latitude'], wp['longitude']))
            .toList() ??
        [];
    
    return Stop(
      name: map['name'] ?? '',
      location: LatLng(locationMap['latitude'], locationMap['longitude']),
      waypointsToNext: waypointsList,
      isWaypoint: map['isWaypoint'] ?? false,
    );
  }
  
  // Create a copy with updated waypoints
  Stop copyWith({
    String? name,
    LatLng? location,
    List<LatLng>? waypointsToNext,
    bool? isWaypoint,
  }) {
    return Stop(
      name: name ?? this.name,
      location: location ?? this.location,
      waypointsToNext: waypointsToNext ?? this.waypointsToNext,
      isWaypoint: isWaypoint ?? this.isWaypoint,
    );
  }
}

class RouteController extends GetxController {
  // Route direction: 'up' (Home → School) or 'down' (School → Home)
  var currentDirection = 'up'.obs;
  
  // Separate stops for UP and DOWN routes
  var upStops = <Stop>[].obs;
  var downStops = <Stop>[].obs;
  
  // Computed getter for current stops based on direction
  RxList<Stop> get stops => currentDirection.value == 'up' ? upStops : downStops;
  
  // Separate polylines for UP and DOWN routes
  var upRoutePolyline = <LatLng>[].obs;
  var downRoutePolyline = <LatLng>[].obs;
  
  // Computed getter for current polyline based on direction
  RxList<LatLng> get routePolyline => currentDirection.value == 'up' ? upRoutePolyline : downRoutePolyline;
  
  // Indicates whether the app is in "add stop" mode.
  var isAddingStop = false.obs;
  // Loading state for route calculation
  var isLoadingRoute = false.obs;

  late final String _uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _routeId;
  String? _assignedBusId; // Track which bus is assigned to this route

  // Store the last fetched OSRM route distance (in meters) for each direction
  var upRouteDistance = 0.0.obs;
  var downRouteDistance = 0.0.obs;
  
  // Computed getter for current distance
  RxDouble get osrmRouteDistance => currentDirection.value == 'up' ? upRouteDistance : downRouteDistance;

  // Initialize with the route ID and schoolId
  void init(String routeId, {String? schoolId}) {
    _routeId = routeId;
    
    // Get schoolId from parameter, arguments, or throw error
    if (schoolId != null && schoolId.isNotEmpty) {
      _uid = schoolId;
    } else {
      final arguments = Get.arguments as Map<String, dynamic>?;
      _uid = arguments?['schoolId'] ?? '';
      if (_uid.isEmpty) {
        throw Exception('RouteController initialized without schoolId. Please pass schoolId.');
      }
    }

    _loadStops();
  }

  // Switch between UP and DOWN routes
  void switchDirection(String direction) {
    if (direction != 'up' && direction != 'down') return;
    currentDirection.value = direction;
  }

  // Get frozen route stops (opposite direction for reference)
  List<Stop> getFrozenStops() {
    return currentDirection.value == 'up' ? downStops : upStops;
  }

  // Get frozen route polyline (opposite direction for reference)
  List<LatLng> getFrozenPolyline() {
    return currentDirection.value == 'up' ? downRoutePolyline : upRoutePolyline;
  }

  // Listen to Firestore for changes in stops.
  void _loadStops() {
    _firestore
        .collection('schooldetails')
        .doc(_uid)
        .collection('routes')
        .doc(_routeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        
        // Track assigned bus ID
        _assignedBusId = data['assignedBusId'] as String?;

        // Load UP stops
        if (data.containsKey('upStops')) {
          final upStopsData = data['upStops'] as List<dynamic>;
          upStops.value = upStopsData
              .map((stop) => Stop.fromMap(stop as Map<String, dynamic>))
              .toList();
          
          // Auto-calculate road-aware route for UP when stops are loaded
          if (upStops.length >= 2) {
            updateRoutePolyline(direction: 'up');
          } else if (upStops.isEmpty) {
            upRoutePolyline.value = [];
          }
        }

        // Load DOWN stops
        if (data.containsKey('downStops')) {
          final downStopsData = data['downStops'] as List<dynamic>;
          downStops.value = downStopsData
              .map((stop) => Stop.fromMap(stop as Map<String, dynamic>))
              .toList();
          
          // Auto-calculate road-aware route for DOWN when stops are loaded
          if (downStops.length >= 2) {
            updateRoutePolyline(direction: 'down');
          } else if (downStops.isEmpty) {
            downRoutePolyline.value = [];
          }
        }

        // Load distances
        if (data.containsKey('upDistance')) {
          upRouteDistance.value = (data['upDistance'] as num).toDouble();
        }
        if (data.containsKey('downDistance')) {
          downRouteDistance.value = (data['downDistance'] as num).toDouble();
        }
      } else {
        upStops.value = [];
        downStops.value = [];
        upRoutePolyline.value = [];
        downRoutePolyline.value = [];
      }
    }, onError: (error) {
      Get.snackbar('Error', 'Failed to load route: $error');
    });
  }

  // Update Firestore with the current stops.
  Future<void> updateFirestore() async {
    try {
      // Update route document
      await _firestore
          .collection('schooldetails')
          .doc(_uid)
          .collection('routes')
          .doc(_routeId)
          .update({
        'upStops': upStops.map((stop) => stop.toMap()).toList(),
        'downStops': downStops.map((stop) => stop.toMap()).toList(),
        // Polylines removed - generated on-demand via OSRM, not stored in database
        'upDistance': upRouteDistance.value,
        'downDistance': downRouteDistance.value,
        'totalDistance': upRouteDistance.value + downRouteDistance.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to update route: $e');
    }
  }
  
  /// Sync route stops to the assigned bus document
  /// This ensures Time Control and Student Stop Location screens work correctly

  /// Fetch road-aware route polyline using OSRM
  /// Creates ONE main route from start to end, with stops as zones along the way
  /// Can specify direction ('up' or 'down') or use current direction
  Future<void> updateRoutePolyline({String? direction}) async {
    final dir = direction ?? currentDirection.value;
    final stopsToUse = dir == 'up' ? upStops : downStops;
    final polylineToUpdate = dir == 'up' ? upRoutePolyline : downRoutePolyline;
    final distanceToUpdate = dir == 'up' ? upRouteDistance : downRouteDistance;
    
    if (stopsToUse.isEmpty) {
      polylineToUpdate.value = [];
      distanceToUpdate.value = 0.0;
      if (direction == null) isLoadingRoute.value = false;
      return;
    }
    
    if (stopsToUse.length == 1) {
      // Just one stop, show a point
      polylineToUpdate.value = [stopsToUse.first.location];
      distanceToUpdate.value = 0.0;
      if (direction == null) isLoadingRoute.value = false;
      return;
    }

    if (direction == null) isLoadingRoute.value = true;
    
    try {
      // Create route from first to last stop, passing through ALL intermediate stops
      final origin = stopsToUse.first.location;
      final destination = stopsToUse.last.location;
      
      // Build waypoints list: intermediate stops + any custom waypoints
      List<LatLng> allWaypoints = [];
      
      // Add all intermediate stops (skip first and last)
      for (int i = 1; i < stopsToUse.length - 1; i++) {
        allWaypoints.add(stopsToUse[i].location);
        
        // Also add any custom waypoints after this stop
        if (stopsToUse[i].waypointsToNext.isNotEmpty) {
          allWaypoints.addAll(stopsToUse[i].waypointsToNext);
        }
      }
      
      // Get road-aware route from OSRM with timeout
      final route = await OSRMService.getDirections(
        origin: origin,
        destination: destination,
        waypoints: allWaypoints.isNotEmpty ? allWaypoints : null,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return null;
        },
      );
      
      if (route != null && route.polylinePoints.isNotEmpty) {
        polylineToUpdate.value = route.polylinePoints;
        distanceToUpdate.value = route.distanceMeters.toDouble();
      } else {
        // Fallback: straight line
        polylineToUpdate.value = [origin, destination];
        
        // Calculate straight distance
        const Distance distance = Distance();
        distanceToUpdate.value = distance.as(
          LengthUnit.Meter,
          origin,
          destination,
        );
      }
      
      if (direction == null) isLoadingRoute.value = false;
      
    } catch (e) {
      // Fallback: draw straight line from start to end
      if (stopsToUse.length >= 2) {
        polylineToUpdate.value = [stopsToUse.first.location, stopsToUse.last.location];
        distanceToUpdate.value = 0.0;
      }
      
      if (direction == null) isLoadingRoute.value = false;
    }
  }

  // Calculate the total distance of the route.
  // Now returns the OSRM route distance if available, otherwise falls back to straight-line.
  double calculateDistance() {
    if (osrmRouteDistance.value > 0) {
      return osrmRouteDistance.value;
    }
    const Distance distance = Distance();
    double totalDistance = 0.0;

    for (int i = 0; i < stops.length - 1; i++) {
      totalDistance += distance.as(
        LengthUnit.Meter,
        stops[i].location,
        stops[i + 1].location,
      );
    }

    return totalDistance;
  }

  /// Simple validation - only check if stop is too close to existing ones
  /// Road snapping handles the rest automatically
  Future<bool> validateNewStop(Stop newStop) async {
    if (stops.isEmpty) {
      return true; // First stop, always OK
    }

    // Only check if new stop is too close to existing stops (within 50m)
    // This prevents duplicate stops, but allows any side of the road
    const Distance distance = Distance();
    for (var existingStop in stops) {
      final dist = distance.as(
        LengthUnit.Meter,
        existingStop.location,
        newStop.location,
      );
      if (dist < 50) {
        Get.snackbar(
          '⚠️ Stop Too Close',
          'This location is within 50m of an existing stop "${existingStop.name}". Please choose a different location.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
        );
        return false;
      }
    }

    return true; // Allow all other stops - routing will handle the path
  }

  // Methods to add, remove, and edit stops.
  Future<void> addStop(Stop stop) async {
    // Validate the stop first
    final isValid = await validateNewStop(stop);
    if (!isValid) return;
    
    // 🛣️ SNAP TO ROAD: Ensure stop is on a drivable road using OSRM
    // This prevents issues with Ola Maps Directions API later
    print('📍 Original location: ${stop.location.latitude}, ${stop.location.longitude}');
    final snappedLocation = await OSRMService.snapToRoad(stop.location) ?? stop.location;
    
    // Calculate distance between original and snapped location
    const Distance distance = Distance();
    final snapDistance = distance.as(LengthUnit.Meter, stop.location, snappedLocation);
    
    if (snapDistance > 0.1) { // More than 10cm difference
      print('🛣️ Snapped to road: ${snappedLocation.latitude}, ${snappedLocation.longitude}');
      print('   Distance adjusted: ${snapDistance.toStringAsFixed(1)}m');
      
      // Show user feedback if snap distance is significant (>50m)
      if (snapDistance > 50) {
        Get.snackbar(
          'Stop Location Adjusted',
          'Stop moved ${snapDistance.toStringAsFixed(0)}m to nearest road',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
    
    // Create stop with snapped location
    final roadSnappedStop = stop.copyWith(location: snappedLocation);
    
    // Add to current direction's stops
    if (currentDirection.value == 'up') {
      upStops.add(roadSnappedStop);
    } else {
      downStops.add(roadSnappedStop);
    }
    updateFirestore();
    updateRoutePolyline();
  }

  void removeStop(int index) {
    // Remove from current direction's stops
    if (currentDirection.value == 'up') {
      upStops.removeAt(index);
    } else {
      downStops.removeAt(index);
    }
    updateFirestore();
    updateRoutePolyline();
  }

  Future<void> editStop(int index, Stop newStop) async {
    // 🛣️ SNAP TO ROAD: Ensure edited stop is also on a drivable road
    print('📍 Original edited location: ${newStop.location.latitude}, ${newStop.location.longitude}');
    final snappedLocation = await OSRMService.snapToRoad(newStop.location) ?? newStop.location;
    
    // Calculate distance between original and snapped location
    const Distance distance = Distance();
    final snapDistance = distance.as(LengthUnit.Meter, newStop.location, snappedLocation);
    
    if (snapDistance > 0.1) {
      print('🛣️ Snapped edited stop to road: ${snappedLocation.latitude}, ${snappedLocation.longitude}');
      print('   Distance adjusted: ${snapDistance.toStringAsFixed(1)}m');
      
      if (snapDistance > 50) {
        Get.snackbar(
          'Stop Location Adjusted',
          'Stop moved ${snapDistance.toStringAsFixed(0)}m to nearest road',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
    
    final roadSnappedStop = newStop.copyWith(location: snappedLocation);
    
    // Edit in current direction's stops
    if (currentDirection.value == 'up') {
      upStops[index] = roadSnappedStop;
    } else {
      downStops[index] = roadSnappedStop;
    }
    updateFirestore();
    updateRoutePolyline();
  }
  
  /// Add a waypoint between two stops to control the route path
  /// stopIndex: the index of the stop BEFORE which the waypoint affects routing
  void addWaypoint(int stopIndex, LatLng waypointLocation) {
    if (stopIndex < 0 || stopIndex >= stops.length) return;
    
    final currentStop = stops[stopIndex];
    final updatedWaypoints = List<LatLng>.from(currentStop.waypointsToNext)
      ..add(waypointLocation);
    
    stops[stopIndex] = currentStop.copyWith(waypointsToNext: updatedWaypoints);
    
    Get.snackbar(
      '✅ Waypoint Added',
      'Route will now pass through this point',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    
    updateFirestore();
    updateRoutePolyline();
  }
  
  /// Remove a waypoint
  void removeWaypoint(int stopIndex, int waypointIndex) {
    if (stopIndex < 0 || stopIndex >= stops.length) return;
    
    final currentStop = stops[stopIndex];
    if (waypointIndex < 0 || waypointIndex >= currentStop.waypointsToNext.length) return;
    
    final updatedWaypoints = List<LatLng>.from(currentStop.waypointsToNext)
      ..removeAt(waypointIndex);
    
    stops[stopIndex] = currentStop.copyWith(waypointsToNext: updatedWaypoints);
    
    updateFirestore();
    updateRoutePolyline();
  }
  
  /// Clear all waypoints for a stop
  void clearWaypoints(int stopIndex) {
    if (stopIndex < 0 || stopIndex >= stops.length) return;
    
    final currentStop = stops[stopIndex];
    stops[stopIndex] = currentStop.copyWith(waypointsToNext: []);
    
    updateFirestore();
    updateRoutePolyline();
  }
  
  /// 🛠️ FIX EXISTING ROUTES: Snap all stops to nearest road
  /// This should be called once to fix any off-road stops in existing routes
  Future<void> snapAllStopsToRoad({bool showProgress = true}) async {
    if (stops.isEmpty) {
      Get.snackbar(
        'No Stops',
        'No stops to snap to road',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    if (showProgress) {
      Get.snackbar(
        '🛣️ Snapping Stops to Road',
        'Adjusting ${stops.length} stops to nearest roads...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
    
    int adjustedCount = 0;
    double totalAdjustment = 0;
    
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final snappedLocation = await OSRMService.snapToRoad(stop.location) ?? stop.location;
      
      const Distance distance = Distance();
      final snapDistance = distance.as(LengthUnit.Meter, stop.location, snappedLocation);
      
      if (snapDistance > 0.1) {
        print('🛣️ Stop ${i + 1} "${stop.name}": adjusted ${snapDistance.toStringAsFixed(1)}m');
        
        // Update stop with snapped location
        if (currentDirection.value == 'up') {
          upStops[i] = stop.copyWith(location: snappedLocation);
        } else {
          downStops[i] = stop.copyWith(location: snappedLocation);
        }
        
        adjustedCount++;
        totalAdjustment += snapDistance;
      }
    }
    
    if (adjustedCount > 0) {
      // Save to Firestore
      await updateFirestore();
      await updateRoutePolyline();
      
      if (showProgress) {
        Get.snackbar(
          '✅ Stops Adjusted',
          '$adjustedCount stops moved to roads (avg ${(totalAdjustment / adjustedCount).toStringAsFixed(0)}m)',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
      
      print('✅ Route snap complete: $adjustedCount/$stops.length stops adjusted');
    } else {
      if (showProgress) {
        Get.snackbar(
          '✅ All Good',
          'All stops are already on roads',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
      
      print('✅ All stops already on roads');
    }
  }
}
