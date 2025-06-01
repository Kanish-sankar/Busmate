import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String id;
  final String busNo;
  final String driverName;
  final String busVehicleNo;
  final String driverId;
  final String routeName;
  final List<Map<String, dynamic>> stoppings;
  final List<String> students;
  final String gpsType;

  Bus({
    required this.id,
    required this.busNo,
    required this.driverName,
    required this.busVehicleNo,
    required this.driverId,
    required this.routeName,
    this.stoppings = const [],
    this.students = const [],
    required this.gpsType,
  });

  factory Bus.fromDocument(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Bus(
      id: doc.id,
      busNo: data['busNo'] ?? '',
      driverName: data['driverName'] ?? '',
      driverId: data['driverId'] ?? '',
      busVehicleNo: data['busVehicleNo'] ?? '',
      routeName: data['routeName'] ?? '',
      stoppings: List<Map<String, dynamic>>.from(data['stoppings'] ?? []),
      students: List<String>.from(data['students'] ?? []),
      gpsType: data['gpsType'] ?? 'Software',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNo': busNo,
      'driverName': driverName,
      'driverId': driverId,
      'busVehicleNo': busVehicleNo,
      'routeName': routeName,
      'stoppings': stoppings,
      'students': students,
      'gpsType': gpsType,
    };
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
