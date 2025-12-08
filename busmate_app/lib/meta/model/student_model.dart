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
  bool notified; // Track if student has been notified for current trip
  GeoPoint? stopLocation; // Student's stop coordinates for location-based matching

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
    this.notified = false,
    this.stopLocation,
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
      notified: data['notified'] ?? false,
      stopLocation: data['stopLocation'] != null
          ? (data['stopLocation'] is GeoPoint
              ? data['stopLocation'] as GeoPoint
              : GeoPoint(
                  (data['stopLocation']['latitude'] ?? 0.0) as double,
                  (data['stopLocation']['longitude'] ?? 0.0) as double,
                ))
          : null,
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
      'fcmToken': fcmToken,
      'notificationType': notificationType,
      'parentContact': parentContact,
      'password': password,
      'rollNumber': rollNumber,
      'schoolId': schoolId,
      'stopping': stopping,
      'studentClass': studentClass,
      'siblings': siblings,
      'notified': notified,
      'stopLocation': stopLocation,
    };
  }

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignedBusId': assignedBusId,
      'assignedDriverId': assignedDriverId,
      'email': email,
      'languagePreference': languagePreference,
      'name': name,
      'notificationPreferenceByLocation': notificationPreferenceByLocation,
      'notificationPreferenceByTime': notificationPreferenceByTime,
      'fcmToken': fcmToken,
      'notificationType': notificationType,
      'parentContact': parentContact,
      'password': password,
      'rollNumber': rollNumber,
      'schoolId': schoolId,
      'stopping': stopping,
      'studentClass': studentClass,
      'siblings': siblings,
      'notified': notified,
      'stopLocation': stopLocation != null
          ? {'latitude': stopLocation!.latitude, 'longitude': stopLocation!.longitude}
          : null,
    };
  }

  // Create from JSON (for cache retrieval)
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] ?? '',
      assignedBusId: json['assignedBusId'] ?? '',
      assignedDriverId: json['assignedDriverId'] ?? '',
      email: json['email'] ?? '',
      languagePreference: json['languagePreference'] ?? '',
      name: json['name'] ?? '',
      notificationPreferenceByLocation: json['notificationPreferenceByLocation'] ?? '',
      notificationPreferenceByTime: json['notificationPreferenceByTime'] ?? 5,
      fcmToken: json['fcmToken'] ?? '',
      notificationType: json['notificationType'] ?? '',
      parentContact: json['parentContact'] ?? '',
      password: json['password'] ?? '',
      rollNumber: json['rollNumber'] ?? '',
      schoolId: json['schoolId'] ?? '',
      stopping: json['stopping'] ?? '',
      studentClass: json['studentClass'] ?? '',
      siblings: (json['siblings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      notified: json['notified'] ?? false,
      stopLocation: json['stopLocation'] != null
          ? GeoPoint(
              (json['stopLocation']['latitude'] ?? 0.0) as double,
              (json['stopLocation']['longitude'] ?? 0.0) as double,
            )
          : null,
    );
  }
}