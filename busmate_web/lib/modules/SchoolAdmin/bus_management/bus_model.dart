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
  
  // Route information (assigned later)
  final String? routeId;
  final String? routeName;
  final List<Map<String, dynamic>> stoppings; // [{name, lat, lng, time, sequence}]
  
  // Student assignments (assigned last)
  final List<String> assignedStudents; // List of student IDs
  
  // Status tracking
  final String status; // 'active', 'inactive', 'maintenance'
  final bool isOperational;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastServiceDate;
  final DateTime? nextServiceDate;
  
  // Additional info
  final String? manufacturer;
  final String? model;
  final int? yearOfManufacture;
  final String? notes;

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
    this.routeId,
    this.routeName,
    this.stoppings = const [],
    this.assignedStudents = const [],
    this.status = 'active',
    this.isOperational = true,
    required this.createdAt,
    this.updatedAt,
    this.lastServiceDate,
    this.nextServiceDate,
    this.manufacturer,
    this.model,
    this.yearOfManufacture,
    this.notes,
  });

  // Check if driver is assigned
  bool get hasDriver => driverId != null && driverId!.isNotEmpty;
  
  // Check if route is assigned
  bool get hasRoute => routeId != null && routeId!.isNotEmpty;
  
  // Check if needs service
  bool get needsService {
    if (nextServiceDate == null) return false;
    return DateTime.now().isAfter(nextServiceDate!);
  }

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
      routeId: data['routeId'],
      routeName: data['routeName'],
      stoppings: List<Map<String, dynamic>>.from(data['stoppings'] ?? []),
      assignedStudents: List<String>.from(data['assignedStudents'] ?? []),
      status: data['status'] ?? 'active',
      isOperational: data['isOperational'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastServiceDate: (data['lastServiceDate'] as Timestamp?)?.toDate(),
      nextServiceDate: (data['nextServiceDate'] as Timestamp?)?.toDate(),
      manufacturer: data['manufacturer'],
      model: data['model'],
      yearOfManufacture: data['yearOfManufacture'],
      notes: data['notes'],
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
      'routeId': routeId,
      'routeName': routeName,
      'stoppings': stoppings,
      'assignedStudents': assignedStudents,
      'status': status,
      'isOperational': isOperational,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'lastServiceDate': lastServiceDate != null ? Timestamp.fromDate(lastServiceDate!) : null,
      'nextServiceDate': nextServiceDate != null ? Timestamp.fromDate(nextServiceDate!) : null,
      'manufacturer': manufacturer,
      'model': model,
      'yearOfManufacture': yearOfManufacture,
      'notes': notes,
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
    List<String>? assignedStudents,
    String? status,
    bool? isOperational,
    DateTime? updatedAt,
    DateTime? lastServiceDate,
    DateTime? nextServiceDate,
    String? notes,
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
      assignedStudents: assignedStudents ?? this.assignedStudents,
      status: status ?? this.status,
      isOperational: isOperational ?? this.isOperational,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      manufacturer: manufacturer,
      model: model,
      yearOfManufacture: yearOfManufacture,
      notes: notes ?? this.notes,
    );
  }
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