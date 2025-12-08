import 'package:latlong2/latlong.dart';

/// Model for real-time bus location data
class BusLocation {
  final String busId;
  final String schoolId;
  final double latitude;
  final double longitude;
  final double? speed; // km/h
  final double? heading; // degrees (0-360)
  final DateTime timestamp;
  final String? driverId;
  final String? driverName;
  final String? routeId;
  final String? routeName;
  final BusStatus status;
  final int? batteryLevel;
  final int? totalStudents;
  final String? currentStop;
  final String? nextStop;
  final DateTime? estimatedArrival;
  final bool isOnline;

  BusLocation({
    required this.busId,
    required this.schoolId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    required this.timestamp,
    this.driverId,
    this.driverName,
    this.routeId,
    this.routeName,
    this.status = BusStatus.idle,
    this.batteryLevel,
    this.totalStudents,
    this.currentStop,
    this.nextStop,
    this.estimatedArrival,
    this.isOnline = false,
  });

  LatLng get location => LatLng(latitude, longitude);

  /// Create from Realtime Database snapshot
  factory BusLocation.fromRealtimeDb(String busId, String schoolId, Map<dynamic, dynamic> data) {
    return BusLocation(
      busId: busId,
      schoolId: schoolId,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (data['speed'] as num?)?.toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      routeId: data['routeId'] as String?,
      routeName: data['routeName'] as String?,
      status: _parseStatus(data['status'] as String?),
      batteryLevel: (data['batteryLevel'] as num?)?.toInt(),
      totalStudents: (data['totalStudents'] as num?)?.toInt(),
      currentStop: data['currentStop'] as String?,
      nextStop: data['nextStop'] as String?,
      estimatedArrival: data['estimatedArrival'] != null
          ? DateTime.fromMillisecondsSinceEpoch((data['estimatedArrival'] as num).toInt())
          : null,
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }

  /// Convert to Realtime Database format
  Map<String, dynamic> toRealtimeDb() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (routeId != null) 'routeId': routeId,
      if (routeName != null) 'routeName': routeName,
      'status': status.name,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (totalStudents != null) 'totalStudents': totalStudents,
      if (currentStop != null) 'currentStop': currentStop,
      if (nextStop != null) 'nextStop': nextStop,
      if (estimatedArrival != null) 'estimatedArrival': estimatedArrival!.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'isActive': isOnline, // Firebase Function checks this field
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  static BusStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'moving':
        return BusStatus.moving;
      case 'stopped':
        return BusStatus.stopped;
      case 'idle':
        return BusStatus.idle;
      default:
        return BusStatus.idle;
    }
  }

  /// Check if location is stale (older than 5 minutes)
  bool get isStale {
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes > 5;
  }

  /// Get time since last update
  String get timeSinceUpdate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  BusLocation copyWith({
    String? busId,
    String? schoolId,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? driverId,
    String? driverName,
    String? routeId,
    String? routeName,
    BusStatus? status,
    int? batteryLevel,
    int? totalStudents,
    String? currentStop,
    String? nextStop,
    DateTime? estimatedArrival,
    bool? isOnline,
  }) {
    return BusLocation(
      busId: busId ?? this.busId,
      schoolId: schoolId ?? this.schoolId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      totalStudents: totalStudents ?? this.totalStudents,
      currentStop: currentStop ?? this.currentStop,
      nextStop: nextStop ?? this.nextStop,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      isOnline: isOnline ?? this.isOnline,
    );
  }
  
  /// Convert to JSON for Firestore (web compatible)
  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'schoolId': schoolId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
      'driverId': driverId,
      'driverName': driverName,
      'routeId': routeId,
      'routeName': routeName,
      'status': status.toString().split('.').last,
      'batteryLevel': batteryLevel,
      'totalStudents': totalStudents,
      'currentStop': currentStop,
      'nextStop': nextStop,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'isOnline': isOnline,
    };
  }
  
  /// Create from JSON (Firestore - web compatible)
  factory BusLocation.fromJson(Map<String, dynamic> json) {
    return BusLocation(
      busId: json['busId'] as String,
      schoolId: json['schoolId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      driverId: json['driverId'] as String,
      driverName: json['driverName'] as String,
      routeId: json['routeId'] as String,
      routeName: json['routeName'] as String,
      status: _statusFromString(json['status'] as String?),
      batteryLevel: json['batteryLevel'] as int?,
      totalStudents: json['totalStudents'] as int,
      currentStop: json['currentStop'] as String?,
      nextStop: json['nextStop'] as String?,
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'] as String)
          : null,
      isOnline: json['isOnline'] as bool,
    );
  }
  
  static BusStatus _statusFromString(String? status) {
    switch (status) {
      case 'moving':
        return BusStatus.moving;
      case 'stopped':
        return BusStatus.stopped;
      case 'idle':
        return BusStatus.idle;
      default:
        return BusStatus.idle;
    }
  }
}

/// Bus status enum
enum BusStatus {
  moving,
  stopped,
  idle,
}
