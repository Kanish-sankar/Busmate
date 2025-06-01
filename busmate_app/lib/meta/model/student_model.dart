import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  String id;
  String assignedBusId;
  String assignedDriverId;
  String email;
  String languagePreference;
  String name;
  String notificationPreferenceByLocation;
  int notificationPreferenceByTime;
  String fcmToken;
  String notificationType;
  String parentContact;
  String password;
  String rollNumber;
  String schoolId;
  String stopping;
  String studentClass;
  List<String> siblings;

  StudentModel({
    required this.id,
    required this.assignedBusId,
    required this.assignedDriverId,
    required this.email,
    required this.languagePreference,
    required this.name,
    required this.notificationPreferenceByLocation,
    required this.notificationPreferenceByTime,
    required this.fcmToken,
    required this.notificationType,
    required this.parentContact,
    required this.password,
    required this.rollNumber,
    required this.schoolId,
    required this.stopping,
    required this.studentClass,
    required this.siblings,
  });

  // Convert Firestore document to StudentModel
  factory StudentModel.fromMap(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      assignedBusId: data['assignedBusId'] ?? '',
      assignedDriverId: data['assignedDriverId'] ?? '',
      email: data['email'] ?? '',
      languagePreference: data['languagePreference'] ?? '',
      name: data['name'] ?? '',
      notificationPreferenceByLocation:
          data['notificationPreferenceByLocation'] ?? '',
      notificationPreferenceByTime: data['notificationPreferenceByTime'] ?? 5,
      fcmToken: data['fcmToken'] ?? '',
      notificationType: data['notificationType'] ?? '',
      parentContact: data['parentContact'] ?? '',
      password: data['password'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      schoolId: data['schoolId'] ?? '',
      stopping: data['stopping'] ?? '',
      studentClass: data['studentClass'] ?? '',
      siblings: (data['siblings'] as List<dynamic>?)
              ?.map((siblings) => siblings.toString())
              .toList() ??
          [],
    );
  }

  // Convert StudentModel to Firestore document (for saving data)
  Map<String, dynamic> toMap() {
    return {
      'assignedBusId': assignedBusId,
      'assignedDriverId': assignedDriverId,
      'email': email,
      'languagePreference': languagePreference,
      'name': name,
      'notificationPreferenceByLocation': notificationPreferenceByLocation,
      'notificationPreferenceByTime': notificationPreferenceByTime,
      'notificationType': notificationType,
      'parentContact': parentContact,
      'password': password,
      'rollNumber': rollNumber,
      'schoolId': schoolId,
      'stopping': stopping,
      'studentClass': studentClass,
      'siblings': siblings,
    };
  }
}
