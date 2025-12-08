import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String email; // Replaces userId
  final String password; // (Consider not storing plaintext passwords)
  final String name;
  final String licenseNumber;
  final String contactInfo;
  final String profileImageUrl; // URL for profile picture
  final String gpsType; // 'software' or 'hardware'
  final bool available; // Driver's availability status
  final String? assignedBusId; // Bus assigned to the driver
  final String schoolId; // Added schoolId field

  Driver({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.licenseNumber,
    required this.contactInfo,
    required this.profileImageUrl,
    this.gpsType = 'software',
    required this.available,
    required this.assignedBusId,
    required this.schoolId, // Added to constructor
  });

  factory Driver.fromDocument(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Driver(
      id: doc.id,
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      name: data['name'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      gpsType: data['gpsType'] ?? 'software',
      available: data['available'] ?? false,
      assignedBusId: data['assignedBusId'] ?? '',
      schoolId: data['schoolId'] ?? '', // Added to fromDocument
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'licenseNumber': licenseNumber,
      'contactInfo': contactInfo,
      'profileImageUrl': profileImageUrl,
      'gpsType': gpsType,
      'available': available,
      'assignedBusId': assignedBusId,
      'schoolId': schoolId, // Added to toMap
    };
  }
}
