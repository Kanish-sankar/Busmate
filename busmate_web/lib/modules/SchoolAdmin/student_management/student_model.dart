import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String email; // Renamed from userId
  final String password;
  final String name;
  final String rollNumber;
  final String studentClass;
  final String parentContact;
  final String stopping;
  final int notificationPreferenceByTime; // Changed to int
  final String
      notificationPreferenceByLocation; // e.g. "On arival at: Bus stop no2"
  final String notificationType; // e.g. "Push Notification" or "SMS"
  final String languagePreference;
  final String? assignedBusId; // Bus assigned to the student
  final String? assignedDriverId; // Driver assigned to the student
  final String schoolId; // Added schoolId field

  Student({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.rollNumber,
    required this.studentClass,
    required this.parentContact,
    required this.stopping,
    required this.notificationPreferenceByTime, // Updated type
    required this.notificationPreferenceByLocation,
    required this.notificationType,
    required this.languagePreference,
    required this.assignedBusId,
    required this.assignedDriverId,
    required this.schoolId, // Added to constructor
  });

  factory Student.fromDocument(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Student(
      id: doc.id,
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      name: data['name'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      studentClass: data['studentClass'] ?? '',
      parentContact: data['parentContact'] ?? '',
      stopping: data['stopping'] ?? '',
      notificationPreferenceByTime: data['notificationPreferenceByTime'] is int
          ? data['notificationPreferenceByTime']
          : int.tryParse(
                  data['notificationPreferenceByTime']?.toString() ?? '0') ??
              0, // Safely parse to int
      notificationPreferenceByLocation:
          data['notificationPreferenceByLocation'] ?? '',
      notificationType: data['notificationType'] ?? '',
      languagePreference: data['languagePreference'] ?? '',
      assignedBusId: data['assignedBusId'] ?? '',
      assignedDriverId: data['assignedDriverId'] ?? '',

      schoolId: data['schoolId'] ?? '', // Added to fromDocument
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'rollNumber': rollNumber,
      'studentClass': studentClass,
      'parentContact': parentContact,
      'stopping': stopping,
      'notificationPreferenceByTime':
          notificationPreferenceByTime, // Updated type
      'notificationPreferenceByLocation': notificationPreferenceByLocation,
      'notificationType': notificationType,
      'languagePreference': languagePreference,
      'assignedBusId': assignedBusId,
      'assignedDriverId': assignedDriverId,
      'schoolId': schoolId, // Added to toMap
    };
  }
}
