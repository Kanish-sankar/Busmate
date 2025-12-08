import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  String id;
  String assignedBusId;
  bool available;
  String contactInfo;
  String email;
  String licenseNumber;
  String name;
  String password;
  String profileImageUrl;
  String schoolId;

  DriverModel({
    required this.id,
    required this.assignedBusId,
    required this.available,
    required this.contactInfo,
    required this.email,
    required this.licenseNumber,
    required this.name,
    required this.password,
    required this.profileImageUrl,
    required this.schoolId,
  });

  // Convert Firestore document to DriverModel
  factory DriverModel.fromMap(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      assignedBusId: data['assignedBusId'] ?? '',
      available: data['available'] ?? false,
      contactInfo: data['contactInfo'] ?? '',
      email: data['email'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      name: data['name'] ?? '',
      password: data['password'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      schoolId: data['schoolId'] ?? '',
    );
  }

  // Convert DriverModel to Firestore document (for saving data)
  Map<String, dynamic> toMap() {
    return {
      'assignedBusId': assignedBusId,
      'available': available,
      'contactInfo': contactInfo,
      'email': email,
      'licenseNumber': licenseNumber,
      'name': name,
      'password': password,
      'profileImageUrl': profileImageUrl,
      'schoolId': schoolId,
    };
  }

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignedBusId': assignedBusId,
      'available': available,
      'contactInfo': contactInfo,
      'email': email,
      'licenseNumber': licenseNumber,
      'name': name,
      'password': password,
      'profileImageUrl': profileImageUrl,
      'schoolId': schoolId,
    };
  }

  // Create from JSON (for cache retrieval)
  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] ?? '',
      assignedBusId: json['assignedBusId'] ?? '',
      available: json['available'] ?? false,
      contactInfo: json['contactInfo'] ?? '',
      email: json['email'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      name: json['name'] ?? '',
      password: json['password'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
      schoolId: json['schoolId'] ?? '',
    );
  }
}
