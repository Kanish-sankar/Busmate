import 'package:cloud_firestore/cloud_firestore.dart';

class RouteSchedule {
  final String id;
  final String schoolId;
  final String busId;
  final String busVehicleNo;
  final String routeName;
  final String direction; // 'pickup' or 'drop'

  // Optional reference to a Route Management route doc (schooldetails/{schoolId}/routes/{routeId})
  // Used to support multiple routes per bus in admin UI.
  final String? routeRefId;
  final String? routeRefName;
  
  // Schedule configuration
  final List<int> daysOfWeek; // [1,2,3,4,5] = Mon-Fri, [6] = Sat, [7] = Sun
  final String startTime; // Format: "07:00"
  final String endTime; // Format: "09:00"
  
  // Route data
  final List<Map<String, dynamic>> stops; // [{name, location: {lat, lng}, order}]
  final List<Map<String, dynamic>>? routePolyline; // OSRM polyline
  
  // Status
  final bool isActive; // Admin can enable/disable
  
  // Validity period
  final DateTime? validFrom;
  final DateTime? validUntil;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;

  RouteSchedule({
    required this.id,
    required this.schoolId,
    required this.busId,
    required this.busVehicleNo,
    required this.routeName,
    required this.direction,
    this.routeRefId,
    this.routeRefName,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.stops,
    this.routePolyline,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
    required this.createdAt,
    this.updatedAt,
  });

  // Check if schedule is active for current time
  bool isActiveNow() {
    final now = DateTime.now();
    
    // Check validity period
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    
    // Check if today is a scheduled day (1=Mon, 7=Sun)
    if (!daysOfWeek.contains(now.weekday)) return false;
    
    // Check time window
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (currentTime.compareTo(startTime) < 0) return false;
    if (currentTime.compareTo(endTime) > 0) return false;
    
    return isActive;
  }

  // Get day names as string
  String get daysOfWeekString {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return daysOfWeek.map((d) => dayNames[d - 1]).join(', ');
  }

  // Get direction display name
  String get directionDisplayName {
    return direction == 'pickup' ? 'Pickup (Home → School)' : 'Drop (School → Home)';
  }

  factory RouteSchedule.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RouteSchedule(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      busId: data['busId'] ?? '',
      busVehicleNo: data['busVehicleNo'] ?? '',
      routeName: data['routeName'] ?? '',
      direction: data['direction'] ?? 'pickup',
      routeRefId: data['routeRefId'] as String?,
      routeRefName: data['routeRefName'] as String?,
      daysOfWeek: List<int>.from(data['daysOfWeek'] ?? [1, 2, 3, 4, 5]),
      startTime: data['startTime'] ?? '07:00',
      endTime: data['endTime'] ?? '09:00',
      stops: List<Map<String, dynamic>>.from(data['stops'] ?? []),
      routePolyline: data['routePolyline'] != null
          ? List<Map<String, dynamic>>.from(data['routePolyline'])
          : null,
      isActive: data['isActive'] ?? true,
      validFrom: (data['validFrom'] as Timestamp?)?.toDate(),
      validUntil: (data['validUntil'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'busId': busId,
      'busVehicleNo': busVehicleNo,
      'routeName': routeName,
      'direction': direction,
      'routeRefId': routeRefId,
      'routeRefName': routeRefName,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'stops': stops,
      'routePolyline': routePolyline,
      'isActive': isActive,
      'validFrom': validFrom != null ? Timestamp.fromDate(validFrom!) : null,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  RouteSchedule copyWith({
    String? id,
    String? schoolId,
    String? busId,
    String? busVehicleNo,
    String? routeName,
    String? direction,
    String? routeRefId,
    String? routeRefName,
    List<int>? daysOfWeek,
    String? startTime,
    String? endTime,
    List<Map<String, dynamic>>? stops,
    List<Map<String, dynamic>>? routePolyline,
    bool? isActive,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouteSchedule(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      busId: busId ?? this.busId,
      busVehicleNo: busVehicleNo ?? this.busVehicleNo,
      routeName: routeName ?? this.routeName,
      direction: direction ?? this.direction,
      routeRefId: routeRefId ?? this.routeRefId,
      routeRefName: routeRefName ?? this.routeRefName,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      stops: stops ?? this.stops,
      routePolyline: routePolyline ?? this.routePolyline,
      isActive: isActive ?? this.isActive,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
