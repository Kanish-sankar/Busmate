import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OLA Maps Distance Matrix API Service for ETA calculations
/// Optimized for single-call approach with waypoint support
class OlaDistanceMatrixService {
  // OLA Maps API key from https://maps.olakrutrim.com/
  static const String _apiKey = 'c8mw89lGYQ05uglqqr7Val5eUTMRTPqgwMNS6F7h';
  static const String _baseUrl = 'https://api.olamaps.io/routing/v1/distanceMatrix';
  
  // For mobile testing: Use mock data initially (set to false for real API when ready)
  // Mobile apps don't have CORS issues, so real API will work fine
  static const bool _useMockData = false; // Set to true for testing without API calls
  
  /// Validate API key before making requests
  static bool _isApiKeyValid() {
    if (_apiKey == 'YOUR_OLA_MAPS_API_KEY' || _apiKey.isEmpty) {
      print('ERROR: OLA Maps API key not configured. Please set your API key in ola_distance_matrix_service.dart');
      return false;
    }
    return true;
  }

  /// Calculate ETAs for all stops from current bus location (OPTIMIZED - Single API Call)
  /// Sends ALL stops + waypoints in ONE API call for maximum efficiency
  /// Example: 20 stops + 15 waypoints → 1 call with 35 destinations
  /// 
  /// How waypoints work:
  /// - For each stop, include its waypoints BEFORE the stop itself
  /// - API calculates cumulative duration through all waypoints to reach stop
  /// - This ensures ETA matches the ACTUAL route the bus will take
  static Future<Map<int, StopETA>> calculateAllStopETAs({
    required LatLng currentLocation,
    required List<LatLng> stops,
    List<List<LatLng>>? waypointsPerStop, // Waypoints for each stop (empty list if no waypoints)
  }) async {
    if (!_isApiKeyValid()) {
      throw Exception('OLA Maps API key not configured');
    }
    
    if (stops.isEmpty) return {};
    
    // Build destinations array: [waypoint1, waypoint2, stop1, waypoint3, stop2, ...]
    final List<LatLng> destinations = [];
    final List<int> stopIndices = []; // Track which destination indices are actual stops
    
    for (int i = 0; i < stops.length; i++) {
      // Add waypoints before this stop (if any)
      if (waypointsPerStop != null && i < waypointsPerStop.length) {
        destinations.addAll(waypointsPerStop[i]);
      }
      
      // Add the stop itself
      destinations.add(stops[i]);
      stopIndices.add(destinations.length - 1); // Record position of actual stop
    }
    
    print('\n🚀 [OLA MAPS API] Calculating ETAs:');
    print('   - Total stops: ${stops.length}');
    print('   - Total waypoints: ${destinations.length - stops.length}');
    print('   - Total destinations in ONE call: ${destinations.length}');
    print('   - Stop indices: $stopIndices');
    
    // ONE API CALL for all destinations
    final allResults = await _fetchDistanceMatrix(
      origins: [currentLocation],
      destinations: destinations,
    );
    
    print('   ✅ API call successful - received ${allResults.length} results');
    
    // Extract ETAs only for actual stops (not waypoints)
    final Map<int, StopETA> stopETAs = {};
    for (int i = 0; i < stopIndices.length; i++) {
      final destIndex = stopIndices[i];
      if (allResults.containsKey(destIndex)) {
        final eta = allResults[destIndex]!;
        stopETAs[i] = eta.copyWith(stopIndex: i);
        print('   📍 Stop ${i+1}: ${(eta.durationSeconds/60).toStringAsFixed(1)}min, ${(eta.distanceMeters/1000).toStringAsFixed(2)}km');
      }
    }
    
    print('   🎯 Initial ETA calculation complete: ${stopETAs.length}/${stops.length} stops\n');
    return stopETAs;
  }

  /// Recalculate ETAs for remaining stops (called after bus completes a segment)
  /// Uses single API call to check if ETAs have changed due to traffic/delays
  /// Example: After completing segment 1 (stops 1-5), recalculate ETAs for stops 6-20
  static Future<Map<int, StopETA>> recalculateRemainingStopETAs({
    required LatLng currentLocation,
    required List<LatLng> allStops,
    required int stopsPassedCount,
    List<List<LatLng>>? allWaypoints,
  }) async {
    // Skip already passed stops
    if (stopsPassedCount >= allStops.length) {
      print('   ⚠️ [RECALC] All stops passed, no recalculation needed');
      return {};
    }
    
    final remainingStops = allStops.sublist(stopsPassedCount);
    final remainingWaypoints = allWaypoints?.sublist(stopsPassedCount);
    
    print('\n🔄 [OLA MAPS RECALC] Recalculating ETAs:');
    print('   - Stops passed: $stopsPassedCount');
    print('   - Remaining stops: ${remainingStops.length}');
    
    // Calculate ETAs for remaining stops in ONE API call
    final remainingETAs = await calculateAllStopETAs(
      currentLocation: currentLocation,
      stops: remainingStops,
      waypointsPerStop: remainingWaypoints,
    );
    
    // Adjust indices to match original stop list
    final Map<int, StopETA> adjustedETAs = {};
    remainingETAs.forEach((localIndex, eta) {
      adjustedETAs[stopsPassedCount + localIndex] = eta.copyWith(stopIndex: stopsPassedCount + localIndex);
    });
    
    print('   ✅ Recalculation complete: ${adjustedETAs.length} ETAs updated\n');
    return adjustedETAs;
  }

  /// Fetch distance matrix from OLA Maps API
  static Future<Map<int, StopETA>> _fetchDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
  }) async {
    if (origins.isEmpty || destinations.isEmpty) return {};
    
    // Use mock data for testing (mobile apps can use real API - no CORS!)
    if (_useMockData) {
      print('🧪 Using mock ETA data for testing');
      return _generateMockETAs(origins[0], destinations);
    }
    
    // Build request body in OLA Maps format
    final requestBody = {
      'origins': origins.map((loc) => [loc.latitude, loc.longitude]).toList(),
      'destinations': destinations.map((loc) => [loc.latitude, loc.longitude]).toList(),
      'mode': 'driving',
    };
    
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'X-Request-Id': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseDistanceMatrixResponse(data);
      } else if (response.statusCode == 401) {
        throw Exception('API Authentication Error: Invalid API key. Please check your OLA Maps API key.');
      } else if (response.statusCode == 429) {
        throw Exception('API Rate Limit: Too many requests. Please wait and try again.');
      } else {
        print('OLA Maps API Error Response: ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling OLA Distance Matrix API: $e');
      rethrow;
    }
  }

  /// Parse OLA Maps Distance Matrix API response
  static Map<int, StopETA> _parseDistanceMatrixResponse(Map<String, dynamic> data) {
    final Map<int, StopETA> etas = {};
    
    try {
      final rows = data['rows'] as List<dynamic>?;
      if (rows == null || rows.isEmpty) {
        print('Warning: No rows in response');
        return {};
      }
      
      final firstRow = rows[0] as Map<String, dynamic>?;
      if (firstRow == null) {
        print('Warning: First row is null');
        return {};
      }
      
      final elements = firstRow['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) {
        print('Warning: No elements in first row');
        return {};
      }
      
      for (int i = 0; i < elements.length; i++) {
        final element = elements[i] as Map<String, dynamic>;
        
        // Check if route was found
        final status = element['status'] as String?;
        if (status != 'OK') {
          print('Warning: No route found for destination $i, status: $status');
          continue;
        }
        
        // Extract distance (in meters)
        final distanceData = element['distance'] as Map<String, dynamic>?;
        if (distanceData == null) {
          print('Warning: No distance data for destination $i');
          continue;
        }
        final distanceMeters = (distanceData['value'] as num?)?.toDouble() ?? 0.0;
        
        // Extract duration (in seconds) - prefer duration_in_traffic if available
        final durationData = element['duration_in_traffic'] ?? element['duration'];
        if (durationData == null) {
          print('Warning: No duration data for destination $i');
          continue;
        }
        final durationSeconds = (durationData['value'] as num?)?.toInt() ?? 0;
        
        etas[i] = StopETA(
          stopIndex: i,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          calculatedAt: DateTime.now(),
        );
      }
      
      return etas;
    } catch (e) {
      print('Error parsing distance matrix response: $e');
      print('Response data: $data');
      return {};
    }
  }

  /// Generate mock ETA data for testing (calculates realistic ETAs based on straight-line distance)
  /// This is used when _useMockData = true (mobile apps can use real API - no CORS!)
  static Map<int, StopETA> _generateMockETAs(LatLng origin, List<LatLng> destinations) {
    final Map<int, StopETA> etas = {};
    const Distance distance = Distance();
    
    for (int i = 0; i < destinations.length; i++) {
      // Calculate straight-line distance
      final distanceMeters = distance.as(
        LengthUnit.Meter,
        origin,
        destinations[i],
      );
      
      // Estimate duration assuming average speed of 30 km/h
      // Add 20% buffer for traffic/stops
      const estimatedSpeed = 30 / 3.6; // 30 km/h converted to m/s
      final durationSeconds = (distanceMeters / estimatedSpeed * 1.2).round();
      
      etas[i] = StopETA(
        stopIndex: i,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        calculatedAt: DateTime.now(),
      );
    }
    
    return etas;
  }

  /// Smart ETA update strategy - Recalculate after each segment is completed
  /// Segments are calculated dynamically: 4 for ≤20 stops, more for longer routes
  static bool shouldRecalculateETAs({
    required int totalStops,
    required int stopsPassedCount,
    required int lastRecalculationAt,
    DateTime? lastRecalculationTime,
    int maxMinutesBetweenRecalc = 10, // Force recalc after 10 min
  }) {
    // Don't recalculate if no stops passed since last calculation
    if (stopsPassedCount <= lastRecalculationAt) {
      // BUT: Force recalculation if too much time passed (catch traffic changes)
      if (lastRecalculationTime != null) {
        final minutesSinceLastRecalc = DateTime.now().difference(lastRecalculationTime).inMinutes;
        if (minutesSinceLastRecalc >= maxMinutesBetweenRecalc) {
          print('⏰ Forcing recalculation: $minutesSinceLastRecalc min since last update');
          return true;
        }
      }
      return false;
    }
    
    // Don't recalculate if all stops are passed
    if (stopsPassedCount >= totalStops) return false;
    
    // Calculate segment count based on route length
    int segmentCount;
    if (totalStops <= 20) {
      segmentCount = 4;
    } else {
      segmentCount = (totalStops / 5).ceil(); // Max 5 stops per segment
    }
    
    // Calculate stops per segment
    final int stopsPerSegment = (totalStops / segmentCount).ceil();
    
    // Recalculate when a segment is completed
    final int currentSegment = (stopsPassedCount / stopsPerSegment).floor();
    final int lastSegment = (lastRecalculationAt / stopsPerSegment).floor();
    
    return currentSegment > lastSegment;
  }
}

/// Model for Stop ETA information
class StopETA {
  final int stopIndex;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime calculatedAt;

  StopETA({
    required this.stopIndex,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.calculatedAt,
  });

  /// Get distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Get duration in minutes
  int get durationMinutes => (durationSeconds / 60).ceil();

  /// Get ETA (estimated time of arrival)
  DateTime get eta => calculatedAt.add(Duration(seconds: durationSeconds));

  /// Get formatted ETA string
  String get formattedETA {
    final now = DateTime.now();
    final difference = eta.difference(now);
    
    if (difference.isNegative) return 'Arrived';
    
    if (difference.inMinutes < 1) return 'Arriving now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    
    final hours = difference.inHours;
    final mins = difference.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${distanceMeters.toInt()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Check if ETA is stale (older than 5 minutes)
  bool get isStale {
    final now = DateTime.now();
    return now.difference(calculatedAt).inMinutes > 5;
  }

  Map<String, dynamic> toJson() {
    return {
      'stopIndex': stopIndex,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'calculatedAt': calculatedAt.toIso8601String(),
      'eta': eta.toIso8601String(),
    };
  }

  factory StopETA.fromJson(Map<String, dynamic> json) {
    return StopETA(
      stopIndex: json['stopIndex'] as int,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }
  
  /// Create a copy with updated fields
  StopETA copyWith({
    int? stopIndex,
    double? distanceMeters,
    int? durationSeconds,
    DateTime? calculatedAt,
  }) {
    return StopETA(
      stopIndex: stopIndex ?? this.stopIndex,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }
}
