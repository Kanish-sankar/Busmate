import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

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
    List<_SpeedSample>? recentSpeeds,
  }) : _recentSpeeds = recentSpeeds ?? [];

  factory BusStatusModel.fromMap(Map<String, dynamic> data, String busId) {
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

    return BusStatusModel(
      busId: busId,
      schoolId: data['schoolId'] ?? '',
      currentLocation: data['currentLocation'] ?? {},
      latitude: (data['currentLocation']?['latitude'] ?? 0.0).toDouble(),
      longitude: (data['currentLocation']?['longitude'] ?? 0.0).toDouble(),
      currentSpeed: data['currentSpeed']?.toDouble() ?? 0.0,
      currentStatus: data['currentStatus'] ?? 'InActive',
      remainingStops: (data['remainingStops'] as List<dynamic>?)
              ?.map((stop) => StopWithETA.fromMap(stop))
              .toList() ??
          [],
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDelayed: data['isDelayed'] ?? false,
      lastMovedTime: (data['lastMovedTime'] as Timestamp?)?.toDate(),
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      currentSegment: data['currentSegment'],
      busRouteType: data['busRouteType'],
      routePolyline: polyline,
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
    final Distance distance = const Distance();

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
    final Distance distance = const Distance();
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
    final Distance distance = const Distance();
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

  // Main ETA calculation method - single source of truth
  void updateETAs({double delayBufferMinutes = 3.0}) {
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
    double accumulatedDistance =
        0.0; // Distance from the bus's current location to the current stop being processed

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
        accumulatedDistance = distanceToStop; // Initialize accumulated distance
      } else {
        // Distance from the previous stop to the current stop
        final prevStop = remainingStops[i - 1];
        double segmentDistance = _calculateRouteDistance(
          LatLng(prevStop.latitude, prevStop.longitude),
          LatLng(stop.latitude, stop.longitude),
          routePolyline!,
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

  void _updateETAsFallback({double delayBufferMinutes = 3.0}) {
    double avgSpeed = getAverageSpeed();
    if (avgSpeed <= 0) {
      avgSpeed = 20.0 / 3.6; // fallback speed (20 km/h)
    }

    final currentPosition = LatLng(latitude, longitude);
    final currentTime = DateTime.now();
    final Distance distance = const Distance();
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
    required String name,
    required double latitude,
    required double longitude,
    this.estimatedTimeOfArrival,
    this.estimatedMinutesOfArrival,
    this.distanceToStop,
  }) : super(
          name: name,
          latitude: latitude,
          longitude: longitude,
        );

  factory StopWithETA.fromMap(Map<String, dynamic> data) {
    return StopWithETA(
      name: data['name'] ?? '',
      latitude: data['location']['latitude']?.toDouble() ?? 0.0,
      longitude: data['location']['longitude']?.toDouble() ?? 0.0,
      estimatedTimeOfArrival:
          (data['estimatedTimeOfArrival'] as Timestamp?)?.toDate(),
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
    return Stoppings(
      name: data['name'] ?? '',
      latitude: data['location']['latitude']?.toDouble() ?? 0.0,
      longitude: data['location']['longitude']?.toDouble() ?? 0.0,
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

// Helper to determine route type based on initial stop
String determineRouteType(List<Stoppings> stoppings, LatLng initialPosition) {
  if (stoppings.isEmpty) return "pickup";
  final Distance distance = const Distance();
  final first = stoppings.first;
  final last = stoppings.last;

  final distToFirst = distance.as(LengthUnit.Meter, initialPosition,
      LatLng(first.latitude, first.longitude));

  final distToLast = distance.as(
      LengthUnit.Meter, initialPosition, LatLng(last.latitude, last.longitude));

  return (distToFirst < distToLast) ? "pickup" : "drop";
}
