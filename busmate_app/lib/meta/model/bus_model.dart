import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../services/ola_distance_matrix_service.dart';

class BusModel {
  // Static data
  String busNo;
  String driverId;
  String driverName;
  String gpsType;
  String routeName;
  String busVehicleNo;
  List<Stoppings> stoppings;
  List<String> students;

  // Dynamic data
  final Map<String, dynamic> currentLocation;
  final double latitude;
  final double longitude;
  double? currentSpeed;
  String? currentStatus;
  double? estimatedArrival;
  List<Stoppings> remainingStops;

  BusModel({
    // Static data
    required this.busNo,
    required this.driverId,
    required this.driverName,
    required this.gpsType,
    required this.routeName,
    required this.busVehicleNo,
    required this.stoppings,
    required this.students,

    // Dynamic data
    required this.currentLocation,
    required this.latitude,
    required this.longitude,
    this.currentSpeed,
    this.currentStatus,
    this.estimatedArrival,
    required this.remainingStops,
  });

  // Convert Firestore document to BusModel
  factory BusModel.fromMap(Map<String, dynamic> data) {
    return BusModel(
      // Static data
      busNo: data['busNo'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      gpsType: data['gpsType'] ?? '',
      routeName: data['routeName'] ?? '',
      busVehicleNo: data['busVehicleNo'] ?? '',
      stoppings: (data['stoppings'] as List<dynamic>?)
              ?.map((stoppings) => Stoppings.fromMap(stoppings))
              .toList() ??
          [],
      students: (data['students'] as List<dynamic>?)
              ?.map((student) => student.toString())
              .toList() ??
          [],

      // Dynamic data
      currentLocation: data['currentLocation'] ?? {},
      latitude: (data['currentLocation']?['latitude'] ?? 0.0).toDouble(),
      longitude: (data['currentLocation']?['longitude'] ?? 0.0).toDouble(),
      currentSpeed: data['currentSpeed'] ?? 0.0,
      currentStatus: data['currentStatus'] ?? 'InActive',
      estimatedArrival: data['estimatedArrival'] ?? 0.0,
      remainingStops: (data['remainingStops'] as List<dynamic>?)
              ?.map((stop) => Stoppings.fromMap(stop))
              .toList() ??
          [],
    );
  }

  // Convert BusModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      // Static data
      'busNo': busNo,
      'driverId': driverId,
      'driverName': driverName,
      'gpsType': gpsType,
      'routeName': routeName,
      'busVehicleNo': busVehicleNo,
      'stoppings': stoppings.map((stop) => stop.toMap()).toList(),
      'students': students,

      // Dynamic data
      'currentLocation': currentLocation,
      'currentSpeed': currentSpeed,
      'currentStatus': currentStatus,
      'estimatedArrival': estimatedArrival,
      'remainingStops': remainingStops.map((stop) => stop.toMap()).toList(),
    };
  }

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'busNo': busNo,
      'driverId': driverId,
      'driverName': driverName,
      'gpsType': gpsType,
      'routeName': routeName,
      'busVehicleNo': busVehicleNo,
      'stoppings': stoppings.map((stop) => stop.toMap()).toList(),
      'students': students,
      'currentLocation': currentLocation,
      'currentSpeed': currentSpeed,
      'currentStatus': currentStatus,
      'estimatedArrival': estimatedArrival,
      'remainingStops': remainingStops.map((stop) => stop.toMap()).toList(),
    };
  }

  // Create from JSON (for cache retrieval)
  factory BusModel.fromJson(Map<String, dynamic> json) {
    return BusModel(
      busNo: json['busNo'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] ?? '',
      gpsType: json['gpsType'] ?? '',
      routeName: json['routeName'] ?? '',
      busVehicleNo: json['busVehicleNo'] ?? '',
      stoppings: (json['stoppings'] as List<dynamic>?)
              ?.map((stoppings) => Stoppings.fromMap(stoppings))
              .toList() ??
          [],
      students: (json['students'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
      currentLocation: json['currentLocation'] ?? {},
      latitude: (json['currentLocation']?['latitude'] ?? 0.0).toDouble(),
      longitude: (json['currentLocation']?['longitude'] ?? 0.0).toDouble(),
      currentSpeed: json['currentSpeed'],
      currentStatus: json['currentStatus'] ?? 'InActive',
      estimatedArrival: json['estimatedArrival'],
      remainingStops: (json['remainingStops'] as List<dynamic>?)
              ?.map((stop) => Stoppings.fromMap(stop))
              .toList() ??
          [],
    );
  }
}

class BusStatusModel {
  String busId;
  String schoolId;
  Map<String, dynamic> currentLocation;
  double latitude;
  double longitude;
  double? currentSpeed;
  String currentStatus;
  List<StopWithETA> remainingStops;
  DateTime lastUpdated;
  bool isDelayed = false;
  DateTime? lastMovedTime;
  double? lastLatitude;
  double? lastLongitude;
  String? currentSegment; // e.g., "A-B"
  String? busRouteType; // "pickup" or "drop"
  List<LatLng>? routePolyline; // Add this to store the polyline
  String? driverName; // Driver name from Realtime DB
  String? driverId; // Driver ID from Realtime DB
  
  // Segment-based ETA system
  List<BusSegment>? segments; // Route divided into segments for progressive recalculation
  int? currentSegmentNumber; // Which segment is currently in progress (1, 2, 3, 4...)
  int stopsPassedCount = 0; // Number of stops already passed
  int? totalStops; // Total number of stops on route
  int? lastRecalculationAt; // At which stop count was last recalculation done
  bool get isActive => currentStatus == 'Active'; // Check if bus is active
  DateTime? lastETACalculation; // When ETAs were last calculated
  Map<String, DateTime>? lastNotifiedETAs; // Track last notified ETA per stop to prevent duplicates

  // Add for average speed calculation
  List<_SpeedSample> _recentSpeeds = [];

  BusStatusModel({
    required this.busId,
    required this.schoolId,
    required this.currentLocation,
    required this.latitude,
    required this.longitude,
    this.currentSpeed = 0.0,
    this.currentStatus = 'InActive',
    required this.remainingStops,
    required this.lastUpdated,
    this.isDelayed = false,
    this.lastMovedTime,
    this.lastLatitude,
    this.lastLongitude,
    this.currentSegment,
    this.busRouteType,
    this.routePolyline, // Add this parameter
    this.driverName,
    this.driverId,
    this.segments,
    this.currentSegmentNumber,
    this.stopsPassedCount = 0,
    this.totalStops,
    this.lastRecalculationAt,
    this.lastETACalculation,
    this.lastNotifiedETAs,
    List<_SpeedSample>? recentSpeeds,
  }) : _recentSpeeds = recentSpeeds ?? [];

  factory BusStatusModel.fromMap(Map<String, dynamic> data, String busId) {
    // Helper to parse DateTime from both Firestore Timestamp and Realtime DB string
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }
    
    // Deserialize recentSpeeds from Firestore
    List<_SpeedSample> recentSpeeds = [];
    if (data['recentSpeeds'] != null && data['recentSpeeds'] is List) {
      recentSpeeds = (data['recentSpeeds'] as List)
          .where((s) => s != null && s['time'] != null && s['speed'] != null)
          .map((s) => _SpeedSample(
                DateTime.fromMillisecondsSinceEpoch(s['time']),
                (s['speed'] as num).toDouble(),
              ))
          .toList();
    }

    // Deserialize polyline if it exists
    List<LatLng>? polyline;
    if (data['routePolyline'] != null && data['routePolyline'] is List) {
      polyline = (data['routePolyline'] as List)
          .map((point) {
            if (point is Map &&
                point['latitude'] != null &&
                point['longitude'] != null) {
              return LatLng(
                (point['latitude'] as num).toDouble(),
                (point['longitude'] as num).toDouble(),
              );
            }
            return null;
          })
          .whereType<LatLng>()
          .toList();
    }
    
    // Deserialize segments
    List<BusSegment>? segments;
    if (data['segments'] != null && data['segments'] is List) {
      segments = (data['segments'] as List)
          .map((s) => BusSegment.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    }
    
    // Deserialize lastNotifiedETAs
    Map<String, DateTime>? lastNotifiedETAs;
    if (data['lastNotifiedETAs'] != null && data['lastNotifiedETAs'] is Map) {
      lastNotifiedETAs = Map<String, DateTime>.fromEntries(
        (data['lastNotifiedETAs'] as Map).entries.map(
          (e) {
            final dt = parseDateTime(e.value);
            return MapEntry(e.key.toString(), dt ?? DateTime.now());
          },
        ),
      );
    }

    return BusStatusModel(
      busId: busId,
      schoolId: data['schoolId'] ?? '',
      currentLocation: data['currentLocation'] ?? {},
      latitude: (data['latitude'] ?? data['currentLocation']?['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? data['currentLocation']?['longitude'] ?? 0.0).toDouble(),
      currentSpeed: data['currentSpeed']?.toDouble() ?? data['speed']?.toDouble() ?? 0.0,
      currentStatus: data['currentStatus'] ?? data['status'] ?? 'InActive',
      remainingStops: (data['remainingStops'] as List<dynamic>?)
              ?.map((stop) => StopWithETA.fromMap(Map<String, dynamic>.from(stop as Map)))
              .toList() ??
          [],
      lastUpdated: parseDateTime(data['lastUpdated']) ?? DateTime.now(),
      isDelayed: data['isDelayed'] ?? false,
      lastMovedTime: parseDateTime(data['lastMovedTime']),
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      currentSegment: data['currentSegment'],
      busRouteType: data['busRouteType'],
      routePolyline: polyline,
      driverName: data['driverName'],
      driverId: data['driverId'],
      segments: segments,
      currentSegmentNumber: data['currentSegmentNumber'] as int?,
      stopsPassedCount: data['stopsPassedCount'] as int? ?? 0,
      totalStops: data['totalStops'] as int?,
      lastRecalculationAt: data['lastRecalculationAt'] as int?,
      lastETACalculation: parseDateTime(data['lastETACalculation']),
      lastNotifiedETAs: lastNotifiedETAs,
      recentSpeeds: recentSpeeds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'currentLocation': currentLocation,
      'currentSpeed': currentSpeed,
      'currentStatus': currentStatus,
      'remainingStops': remainingStops.map((stop) => stop.toMap()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'isDelayed': isDelayed,
      'lastMovedTime':
          lastMovedTime != null ? Timestamp.fromDate(lastMovedTime!) : null,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'currentSegment': currentSegment,
      'busRouteType': busRouteType,
      'routePolyline': routePolyline
          ?.map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(),
      'segments': segments?.map((s) => s.toJson()).toList(),
      'currentSegmentNumber': currentSegmentNumber,
      'stopsPassedCount': stopsPassedCount,
      'totalStops': totalStops,
      'lastRecalculationAt': lastRecalculationAt,
      'lastETACalculation': lastETACalculation != null
          ? Timestamp.fromDate(lastETACalculation!)
          : null,
      'lastNotifiedETAs': lastNotifiedETAs?.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'recentSpeeds': _recentSpeeds
          .map((s) => {
                'time': s.time.millisecondsSinceEpoch,
                'speed': s.speed,
              })
          .toList(),
    };
  }

  // Helper: Find the closest point on the polyline to a position
  int _findClosestPolylineIndex(LatLng position, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0;
    double minDist = double.infinity;
    int minIdx = 0;
    const Distance distance = Distance();

    for (int i = 0; i < polyline.length; i++) {
      final d = distance.as(LengthUnit.Meter, position, polyline[i]);
      if (d < minDist) {
        minDist = d;
        minIdx = i;
      }
    }
    return minIdx;
  }

  // Helper: Calculate route distance between two points along the polyline
  double _calculateRouteDistance(
      LatLng start, LatLng end, List<LatLng> polyline) {
    if (polyline.isEmpty) return 0.0;
    const Distance distance = Distance();
    final startIdx = _findClosestPolylineIndex(start, polyline);
    final endIdx = _findClosestPolylineIndex(end, polyline);
    if (startIdx == endIdx) return 0.0;

    double dist = 0.0;
    if (startIdx < endIdx) {
      // Calculate distance sequentially from start to end
      for (int i = startIdx; i < endIdx; i++) {
        dist += distance.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      }
    } else {
      // Calculate distance sequentially from end to start
      for (int i = endIdx; i < startIdx; i++) {
        dist += distance.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      }
    }
    return dist;
  }

  // Helper: Find the current segment (A-B, B-C, etc) based on polyline and stops
  String _getCurrentSegment(
      LatLng busPos, List<Stoppings> stops, List<LatLng> polyline) {
    if (stops.isEmpty || polyline.isEmpty) return "N/A";
    const Distance distance = Distance();
    final busIdx = _findClosestPolylineIndex(busPos, polyline);

    // Find which segment (between stops) the bus is closest to
    int closestSeg = 0;
    double minSegDist = double.infinity;

    for (int i = 0; i < stops.length - 1; i++) {
      final stopA = LatLng(stops[i].latitude, stops[i].longitude);
      final stopB = LatLng(stops[i + 1].latitude, stops[i + 1].longitude);
      final aIdx = _findClosestPolylineIndex(stopA, polyline);
      final bIdx = _findClosestPolylineIndex(stopB, polyline);

      if (aIdx == bIdx) continue;

      // Project busIdx onto [aIdx, bIdx]
      if ((busIdx >= aIdx && busIdx <= bIdx) ||
          (busIdx >= bIdx && busIdx <= aIdx)) {
        // Bus is between these stops
        return "${stops[i].name}-${stops[i + 1].name}";
      }

      // Otherwise, find the closest segment
      final segMidIdx = ((aIdx + bIdx) / 2).round();
      final segDist =
          distance.as(LengthUnit.Meter, busPos, polyline[segMidIdx]);
      if (segDist < minSegDist) {
        minSegDist = segDist;
        closestSeg = i;
      }
    }

    // If not between any, return closest segment
    if (stops.length > 1) {
      return "${stops[closestSeg].name}-${stops[closestSeg + 1].name}";
    }
    return stops.first.name;
  }

  // Main ETA calculation method using Ola Maps Distance Matrix API
  Future<void> updateETAs({double delayBufferMinutes = 3.0}) async {
    print('🔍 [ETA] Starting updateETAs - Remaining stops: ${remainingStops.length}');
    
    // Initialize segments if not already done
    if (segments == null || segments!.isEmpty) {
      final totalStops = remainingStops.length;
      if (totalStops > 0) {
        segments = divideIntoSegments(totalStops);
        currentSegmentNumber = 1;
        stopsPassedCount = 0;
        lastNotifiedETAs = {};
        print('🎯 [SEGMENTS] Initialized ${segments!.length} segments for $totalStops stops');
        for (var seg in segments!) {
          print('   Segment ${seg.number}: ${seg.stopCount} stops (indices ${seg.startStopIndex}-${seg.endStopIndex})');
        }
      }
    }
    
    // Check if we should recalculate using Ola Maps
    final shouldRecalculate = OlaDistanceMatrixService.shouldRecalculateETAs(
      totalStops: remainingStops.length,
      stopsPassedCount: stopsPassedCount,
      lastRecalculationAt: lastETACalculation != null ? stopsPassedCount : 0,
      lastRecalculationTime: lastETACalculation,
    );
    
    if (!shouldRecalculate && lastETACalculation != null) {
      // ETAs are still fresh, no need to recalculate
      final timeSinceLastCalc = DateTime.now().difference(lastETACalculation!).inSeconds;
      print('⏭️ [ETA] Skipping recalculation - ETAs calculated ${timeSinceLastCalc}s ago');
      return;
    }
    
    print('🚀 [OLA MAPS] Recalculation triggered:');
    print('   - Total stops: ${remainingStops.length}');
    print('   - Stops passed: $stopsPassedCount');
    print('   - Current segment: $currentSegmentNumber');
    
    try {
      final currentPosition = LatLng(latitude, longitude);
      
      // Extract stop locations
      final stopLocations = remainingStops
          .map((stop) => LatLng(stop.latitude, stop.longitude))
          .toList();
      
      // TODO: Extract waypoints from stop data when waypoint system is active
      // For now, waypoints are null
      const List<List<LatLng>>? waypoints = null;
      
      print('📡 [OLA MAPS] Calling API for ${stopLocations.length} stops...');
      print('   - Bus location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}');
      
      // Calculate ETAs using Ola Maps (ONE API CALL)
      final etaResults = await OlaDistanceMatrixService.calculateAllStopETAs(
        currentLocation: currentPosition,
        stops: stopLocations,
        waypointsPerStop: waypoints,
      );
      
      print('✅ [OLA MAPS] Received ${etaResults.length} ETAs');
      
      // Update stop ETAs with Ola Maps data
      final currentTime = DateTime.now();
      for (int i = 0; i < remainingStops.length; i++) {
        if (etaResults.containsKey(i)) {
          final stopETA = etaResults[i]!;
          final stop = remainingStops[i];
          
          // Store Ola Maps data
          stop.distanceToStop = stopETA.distanceMeters;
          stop.estimatedTimeOfArrival = stopETA.eta;
          stop.estimatedMinutesOfArrival = stopETA.durationMinutes.toDouble();
          
          print('   📍 ${stop.name}: ${stopETA.durationMinutes}min (${(stopETA.distanceMeters/1000).toStringAsFixed(1)}km)');
          
          // Add delay buffer if bus is delayed
          if (isDelayed) {
            stop.estimatedMinutesOfArrival = 
                (stop.estimatedMinutesOfArrival ?? 0) + delayBufferMinutes;
            stop.estimatedTimeOfArrival = currentTime.add(
              Duration(seconds: ((stop.estimatedMinutesOfArrival ?? 0) * 60).round()),
            );
            print('      ⚠️ Delay buffer added: +${delayBufferMinutes}min');
          }
        }
      }
      
      lastETACalculation = currentTime;
      print('✅ [ETA] Ola Maps ETAs updated successfully at ${currentTime.toIso8601String()}');
      
    } catch (e) {
      print('❌ [OLA MAPS] API Error: $e');
      // Fallback to OSRM-based calculation
      print('⚠️ [FALLBACK] Using OSRM calculation instead');
      if (routePolyline == null || routePolyline!.isEmpty) {
        _updateETAsFallback(delayBufferMinutes: delayBufferMinutes);
      } else {
        _updateETAsWithPolyline(delayBufferMinutes: delayBufferMinutes);
      }
    }
  }
  
  // Old OSRM-based calculation (renamed as backup method)
  void _updateETAsWithPolyline({double delayBufferMinutes = 3.0}) {
    if (routePolyline == null || routePolyline!.isEmpty) {
      _updateETAsFallback(delayBufferMinutes: delayBufferMinutes);
      return;
    }

    double avgSpeed = getAverageSpeed();
    if (avgSpeed <= 0) {
      avgSpeed = 20.0 / 3.6; // fallback speed (20 km/h)
    }

    final currentPosition = LatLng(latitude, longitude);
    final currentTime = DateTime.now();
    double accumulatedDistance = 0.0;

    // Update current segment (this part seems okay, keep it)
    if (remainingStops.isNotEmpty) {
      final stops = remainingStops
          .map((s) => Stoppings(
                name: s.name,
                latitude: s.latitude,
                longitude: s.longitude,
              ))
          .toList();
      currentSegment =
          _getCurrentSegment(currentPosition, stops, routePolyline!);
    }

    // Calculate ETAs sequentially (A-B, B-C, C-D) and store distance
    for (int i = 0; i < remainingStops.length; i++) {
      final stop = remainingStops[i];
      double distanceToStop;

      if (i == 0) {
        // Distance from current position to the first stop
        distanceToStop = _calculateRouteDistance(
          currentPosition,
          LatLng(stop.latitude, stop.longitude),
          routePolyline!,
        );
        accumulatedDistance = distanceToStop;
      } else {
        // Distance from the previous stop to the current stop
        final prevStop = remainingStops[i - 1];
        double segmentDistance = _calculateRouteDistance(
          LatLng(prevStop.latitude, prevStop.longitude),
          LatLng(stop.latitude, stop.longitude),
          routePolyline!,
        );
        accumulatedDistance += segmentDistance;
        distanceToStop = accumulatedDistance;
      }

      // Store the calculated distance to this stop
      stop.distanceToStop = distanceToStop;

      // Calculate ETA in seconds
      double timeInSeconds = distanceToStop / avgSpeed;

      // Add delay buffer if delayed
      if (isDelayed) {
        timeInSeconds += delayBufferMinutes * 60;
      }

      // Update stop's ETA
      stop.estimatedTimeOfArrival =
          currentTime.add(Duration(seconds: timeInSeconds.round()));
      stop.estimatedMinutesOfArrival = timeInSeconds / 60;
    }
  }

  void _updateETAsFallback({double delayBufferMinutes = 3.0}) {
    double avgSpeed = getAverageSpeed();
    if (avgSpeed <= 0) {
      avgSpeed = 20.0 / 3.6; // fallback speed (20 km/h)
    }

    final currentPosition = LatLng(latitude, longitude);
    final currentTime = DateTime.now();
    const Distance distance = Distance();
    double accumulatedDistance =
        0.0; // Distance from the bus's current location to the current stop being processed

    // Calculate ETAs sequentially using direct distances and store distance
    for (int i = 0; i < remainingStops.length; i++) {
      final stop = remainingStops[i];
      double distanceToStop;

      if (i == 0) {
        // Distance from current position to the first stop
        distanceToStop = distance.as(
          LengthUnit.Meter,
          currentPosition,
          LatLng(stop.latitude, stop.longitude),
        );
        accumulatedDistance = distanceToStop; // Initialize accumulated distance
      } else {
        // Distance from the previous stop to the current stop (direct distance)
        final prevStop = remainingStops[i - 1];
        double segmentDistance = distance.as(
          LengthUnit.Meter,
          LatLng(prevStop.latitude, prevStop.longitude),
          LatLng(stop.latitude, stop.longitude),
        );
        accumulatedDistance +=
            segmentDistance; // Add segment distance to accumulated total
        distanceToStop =
            accumulatedDistance; // Distance to the current stop is the accumulated distance
      }

      // Store the calculated distance to this stop
      stop.distanceToStop = distanceToStop;

      // Calculate ETA in seconds
      double timeInSeconds = distanceToStop / avgSpeed;

      // Add delay buffer if delayed
      if (isDelayed) {
        timeInSeconds += delayBufferMinutes * 60;
      }

      // Update stop's ETA
      stop.estimatedTimeOfArrival =
          currentTime.add(Duration(seconds: timeInSeconds.round()));
      stop.estimatedMinutesOfArrival = timeInSeconds / 60;
    }
  }

  // Speed calculation methods remain unchanged
  void addSpeedSample(double speed) {
    final now = DateTime.now();
    _recentSpeeds.add(_SpeedSample(now, speed));
    _recentSpeeds.removeWhere((s) => now.difference(s.time).inSeconds > 180);
    if (_recentSpeeds.length > 180) {
      _recentSpeeds.removeAt(0);
    }
  }

  double getAverageSpeed() {
    if (_recentSpeeds.isEmpty) return currentSpeed ?? (20.0 / 3.6);
    final now = DateTime.now();
    final recent = _recentSpeeds
        .where((s) => now.difference(s.time).inSeconds <= 180)
        .toList();
    if (recent.isEmpty) return currentSpeed ?? (20.0 / 3.6);
    return recent.map((s) => s.speed).reduce((a, b) => a + b) / recent.length;
  }
  
  /// Check if a stop has been passed (within 50 meters)
  bool _hasPassedStop(LatLng busLocation, StopWithETA stop) {
    const Distance distance = Distance();
    final distanceToStop = distance.as(
      LengthUnit.Meter,
      busLocation,
      LatLng(stop.latitude, stop.longitude),
    );
    return distanceToStop < 50; // Within 50 meters = passed
  }
  
  /// Update stops passed count and check for segment completion
  /// Returns true if a segment was just completed (triggers recalculation)
  Future<bool> checkAndUpdateSegmentCompletion() async {
    print('\n🔍 [SEGMENT CHECK] Checking segment completion...');
    print('   - Current segment: $currentSegmentNumber/${segments?.length ?? 0}');
    print('   - Stops passed: $stopsPassedCount/${remainingStops.length}');
    
    if (segments == null || remainingStops.isEmpty) {
      print('   ⚠️ No segments or stops');
      return false;
    }
    
    final currentPosition = LatLng(latitude, longitude);
    int newStopsPassedCount = 0;
    
    // Count how many stops have been passed
    for (int i = 0; i < remainingStops.length; i++) {
      if (_hasPassedStop(currentPosition, remainingStops[i])) {
        newStopsPassedCount = i + 1;
        print('   ✓ Stop ${i+1} within 50m: ${remainingStops[i].name}');
      } else {
        break; // Stop counting when we find first non-passed stop
      }
    }
    
    // Check if we've passed more stops since last check
    if (newStopsPassedCount > stopsPassedCount) {
      final oldCount = stopsPassedCount;
      stopsPassedCount = newStopsPassedCount;
      print('   📍 Stops passed updated: $oldCount → $newStopsPassedCount');
      
      // Check if we completed a segment
      for (var segment in segments!) {
        if (segment.status != 'completed' && 
            stopsPassedCount > segment.endStopIndex) {
          // Segment completed!
          segment.status = 'completed';
          segment.completedAt = DateTime.now();
          
          print('\n🎉 [SEGMENT COMPLETE] Segment ${segment.number} finished!');
          print('   - Stops in segment: ${segment.startStopIndex}-${segment.endStopIndex}');
          print('   - Total stops passed: $stopsPassedCount');
          
          // Mark next segment as in progress
          final nextSegmentIndex = segments!.indexWhere(
            (s) => s.number == segment.number + 1
          );
          if (nextSegmentIndex != -1) {
            segments![nextSegmentIndex].status = 'in_progress';
            currentSegmentNumber = segments![nextSegmentIndex].number;
            print('   ➡️ Moving to segment $currentSegmentNumber');
          } else {
            print('   🏁 All segments completed!');
          }
          
          print('   📡 Triggering ETA recalculation...');
          
          // Trigger recalculation
          await updateETAs();
          return true;
        }
      }
    } else {
      print('   ⏸️ No new stops passed (still at $stopsPassedCount)');
    }
    
    return false;
  }
  
  /// Check if parent should be notified for this stop
  /// Prevents duplicate notifications when ETA is recalculated
  bool shouldNotifyParent(String stopName, DateTime newETA) {
    lastNotifiedETAs ??= {};
    
    // Check if we've notified for this stop before
    if (lastNotifiedETAs!.containsKey(stopName)) {
      final lastNotifiedETA = lastNotifiedETAs![stopName]!;
      final timeDifference = newETA.difference(lastNotifiedETA).inMinutes.abs();
      
      // Only notify again if ETA changed by more than 2 minutes
      if (timeDifference < 2) {
        print('   ⏭️ [SKIP NOTIFY] ETA unchanged for $stopName (${timeDifference}min diff)');
        return false; // Don't notify - ETA hasn't changed significantly
      }
      
      print('   📲 [NOTIFY] ETA changed for $stopName: ${timeDifference}min difference');
      print('      Old ETA: ${lastNotifiedETA.toIso8601String()}');
      print('      New ETA: ${newETA.toIso8601String()}');
    } else {
      print('   📲 [NOTIFY] First notification for $stopName');
    }
    
    // Update last notified ETA
    lastNotifiedETAs![stopName] = newETA;
    return true;
  }
}

// Helper class for speed samples (not exported)
class _SpeedSample {
  final DateTime time;
  final double speed;
  _SpeedSample(this.time, this.speed);
}

class StopWithETA extends Stoppings {
  DateTime? estimatedTimeOfArrival;
  double? estimatedMinutesOfArrival;
  double? distanceToStop;

  StopWithETA({
    required super.name,
    required super.latitude,
    required super.longitude,
    this.estimatedTimeOfArrival,
    this.estimatedMinutesOfArrival,
    this.distanceToStop,
  });

  factory StopWithETA.fromMap(Map<String, dynamic> data) {
    // Helper to parse DateTime from both Firestore Timestamp and Realtime DB string
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }
    
    final location = data['location'] is Map 
        ? Map<String, dynamic>.from(data['location'] as Map)
        : data['location'] as Map<String, dynamic>?;
    
    return StopWithETA(
      name: data['name'] ?? '',
      latitude: location?['latitude']?.toDouble() ?? 0.0,
      longitude: location?['longitude']?.toDouble() ?? 0.0,
      estimatedTimeOfArrival: parseDateTime(data['estimatedTimeOfArrival']),
      estimatedMinutesOfArrival: data['estimatedMinutesOfArrival']?.toDouble(),
      distanceToStop: data['distanceToStop']?.toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    if (estimatedTimeOfArrival != null) {
      map['estimatedTimeOfArrival'] =
          Timestamp.fromDate(estimatedTimeOfArrival!);
    }
    if (estimatedMinutesOfArrival != null) {
      map['estimatedMinutesOfArrival'] = estimatedMinutesOfArrival;
    }
    if (distanceToStop != null) {
      map['distanceToStop'] = distanceToStop;
    }
    return map;
  }
}

class Stoppings {
  String name;
  double latitude;
  double longitude;

  Stoppings({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory Stoppings.fromMap(Map<String, dynamic> data) {
    // Handle both formats: nested location object and direct lat/lng
    final location = data['location'] as Map<String, dynamic>?;
    
    return Stoppings(
      name: data['name'] ?? '',
      latitude: location?['latitude']?.toDouble() ?? 
                data['latitude']?.toDouble() ?? 0.0,
      longitude: location?['longitude']?.toDouble() ?? 
                 data['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }
}

/// BusSegment class for tracking route segments
/// Used for progressive ETA recalculation throughout the journey
class BusSegment {
  final int number; // Segment number (1, 2, 3, 4, ...)
  final int startStopIndex; // Index of first stop in segment
  final int endStopIndex; // Index of last stop in segment (inclusive)
  final List<int> stopIndices; // All stop indices in this segment
  String status; // 'pending', 'in_progress', 'completed'
  DateTime? completedAt; // When segment was completed
  
  BusSegment({
    required this.number,
    required this.startStopIndex,
    required this.endStopIndex,
    required this.stopIndices,
    this.status = 'pending',
    this.completedAt,
  });
  
  /// Get number of stops in this segment
  int get stopCount => stopIndices.length;
  
  /// Check if this segment is the first one
  bool get isFirst => number == 1;
  
  /// Check if segment is completed
  bool get isCompleted => status == 'completed';
  
  /// Check if segment is in progress
  bool get isInProgress => status == 'in_progress';
  
  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'startStopIndex': startStopIndex,
      'endStopIndex': endStopIndex,
      'stopIndices': stopIndices,
      'status': status,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
  
  factory BusSegment.fromJson(Map<String, dynamic> json) {
    return BusSegment(
      number: json['number'] as int,
      startStopIndex: json['startStopIndex'] as int,
      endStopIndex: json['endStopIndex'] as int,
      stopIndices: List<int>.from(json['stopIndices'] as List),
      status: json['status'] as String? ?? 'pending',
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

/// Divide route stops into segments based on route length
/// - Routes ≤20 stops: 4 segments
/// - Routes >20 stops: Dynamic segments (max 5 stops per segment)
List<BusSegment> divideIntoSegments(int totalStops) {
  if (totalStops == 0) return [];
  
  // Calculate segment count based on route length
  int segmentCount;
  if (totalStops <= 20) {
    segmentCount = 4; // Default: 4 segments for routes ≤20 stops
  } else {
    segmentCount = (totalStops / 5).ceil(); // Ensure max 5 stops per segment
  }
  
  final int baseSize = totalStops ~/ segmentCount; // Integer division
  final int remainder = totalStops % segmentCount;
  
  final List<BusSegment> segments = [];
  int currentIndex = 0;
  
  for (int i = 0; i < segmentCount; i++) {
    // Distribute remainder across first segments
    final int size = baseSize + (i < remainder ? 1 : 0);
    
    final List<int> stopIndices = List.generate(
      size,
      (j) => currentIndex + j,
    );
    
    segments.add(BusSegment(
      number: i + 1,
      startStopIndex: currentIndex,
      endStopIndex: currentIndex + size - 1,
      stopIndices: stopIndices,
      status: i == 0 ? 'in_progress' : 'pending', // First segment starts immediately
    ));
    
    currentIndex += size;
  }
  
  return segments;
}

// Helper to determine route type based on initial stop
String determineRouteType(List<Stoppings> stoppings, LatLng initialPosition) {
  if (stoppings.isEmpty) return "pickup";
  const Distance distance = Distance();
  final first = stoppings.first;
  final last = stoppings.last;

  final distToFirst = distance.as(LengthUnit.Meter, initialPosition,
      LatLng(first.latitude, first.longitude));

  final distToLast = distance.as(
      LengthUnit.Meter, initialPosition, LatLng(last.latitude, last.longitude));

  return (distToFirst < distToLast) ? "pickup" : "drop";
}
