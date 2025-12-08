import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String id;
  final String schoolId;
  final String busNo;
  final String busVehicleNo;
  final String? gpsDeviceId;
  final String gpsType; // 'software' or 'hardware'
   
  // Driver information (assigned later)
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  
  // Route information (dual routes for pickup/drop)
  final String? pickupRouteId;
  final String? pickupRouteName;
  final String? dropRouteId;
  final String? dropRouteName;
  
  // Legacy route fields (for backward compatibility)
  final String? routeId;
  final String? routeName;
  final List<Map<String, dynamic>> stoppings; // [{name, location: {lat, lng}, ...}]
  final List<Map<String, dynamic>>? routePolyline; // Detailed route path from OSRM
  
  // Student assignments (assigned last)
  final List<String> assignedStudents; // List of student IDs
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  Bus({
    required this.id,
    required this.schoolId,
    required this.busNo,
    required this.busVehicleNo,
    this.gpsDeviceId,
    this.gpsType = 'software',
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.pickupRouteId,
    this.pickupRouteName,
    this.dropRouteId,
    this.dropRouteName,
    this.routeId,
    this.routeName,
    this.stoppings = const [],
    this.routePolyline,
    this.assignedStudents = const [],
    required this.createdAt,
    this.updatedAt,
  });

  // Check if driver is assigned
  bool get hasDriver => driverId != null && driverId!.isNotEmpty;
  
  // Check if routes are assigned
  bool get hasPickupRoute => pickupRouteId != null && pickupRouteId!.isNotEmpty;
  bool get hasDropRoute => dropRouteId != null && dropRouteId!.isNotEmpty;
  bool get hasRoute => routeId != null && routeId!.isNotEmpty;

  factory Bus.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bus(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      busNo: data['busNo'] ?? '',
      busVehicleNo: data['busVehicleNo'] ?? '',
      gpsDeviceId: data['gpsDeviceId'],
      gpsType: data['gpsType'] ?? 'software',
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      pickupRouteId: data['pickupRouteId'],
      pickupRouteName: data['pickupRouteName'],
      dropRouteId: data['dropRouteId'],
      dropRouteName: data['dropRouteName'],
      routeId: data['routeId'],
      routeName: data['routeName'],
      stoppings: List<Map<String, dynamic>>.from(data['stoppings'] ?? []),
      routePolyline: data['routePolyline'] != null 
          ? List<Map<String, dynamic>>.from(data['routePolyline'])
          : null,
      assignedStudents: List<String>.from(data['assignedStudents'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'busNo': busNo,
      'busVehicleNo': busVehicleNo,
      'gpsDeviceId': gpsDeviceId,
      'gpsType': gpsType,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'pickupRouteId': pickupRouteId,
      'pickupRouteName': pickupRouteName,
      'dropRouteId': dropRouteId,
      'dropRouteName': dropRouteName,
      'routeId': routeId,
      'routeName': routeName,
      'stoppings': stoppings,
      'routePolyline': routePolyline,
      'assignedStudents': assignedStudents,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  Bus copyWith({
    String? id,
    String? schoolId,
    String? busNo,
    String? busVehicleNo,
    String? gpsDeviceId,
    String? gpsType,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? routeId,
    String? routeName,
    List<Map<String, dynamic>>? stoppings,
    List<Map<String, dynamic>>? routePolyline,
    List<String>? assignedStudents,
    DateTime? updatedAt,
  }) {
    return Bus(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      busNo: busNo ?? this.busNo,
      busVehicleNo: busVehicleNo ?? this.busVehicleNo,
      gpsDeviceId: gpsDeviceId ?? this.gpsDeviceId,
      gpsType: gpsType ?? this.gpsType,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      stoppings: stoppings ?? this.stoppings,
      routePolyline: routePolyline ?? this.routePolyline,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Segment class for dividing route into manageable chunks
/// Used for progressive ETA recalculation throughout the journey
class Segment {
  final int number; // Segment number (1, 2, 3, 4, ...)
  final int startStopIndex; // Index of first stop in segment
  final int endStopIndex; // Index of last stop in segment (inclusive)
  final List<int> stopIndices; // All stop indices in this segment
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime? completedAt; // When segment was completed
  
  Segment({
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
  
  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
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
  
  /// Create a copy with updated fields
  Segment copyWith({
    String? status,
    DateTime? completedAt,
  }) {
    return Segment(
      number: number,
      startStopIndex: startStopIndex,
      endStopIndex: endStopIndex,
      stopIndices: stopIndices,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Divide route stops into segments based on route length
/// - Routes ≤20 stops: 4 segments
/// - Routes >20 stops: Dynamic segments (max 5 stops per segment)
List<Segment> divideIntoSegments(int totalStops) {
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
  
  final List<Segment> segments = [];
  int currentIndex = 0;
  
  for (int i = 0; i < segmentCount; i++) {
    // Distribute remainder across first segments
    final int size = baseSize + (i < remainder ? 1 : 0);
    
    final List<int> stopIndices = List.generate(
      size,
      (j) => currentIndex + j,
    );
    
    segments.add(Segment(
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

class BusStatusModel {
  final String busId;
  final Map<String, dynamic> currentLocation;
  final double latitude;
  final double longitude;
  final double? currentSpeed;
  final String? currentStatus;
  final double? estimatedArrival;

  BusStatusModel({
    required this.busId,
    required this.currentLocation,
    required this.latitude,
    required this.longitude,
    this.currentSpeed,
    this.currentStatus,
    this.estimatedArrival,
  });

  factory BusStatusModel.fromDocument(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return BusStatusModel(
      busId: doc.id,
      currentLocation: data['currentLocation'] ?? {},
      latitude: (data['currentLocation']?['latitude'] ?? 0.0).toDouble(),
      longitude: (data['currentLocation']?['longitude'] ?? 0.0).toDouble(),
      currentSpeed: data['currentSpeed']?.toDouble(),
      currentStatus: data['currentStatus'],
      estimatedArrival: data['estimatedArrival']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentLocation': currentLocation,
      'currentSpeed': currentSpeed,
      'currentStatus': currentStatus,
      'estimatedArrival': estimatedArrival,
    };
  }
}