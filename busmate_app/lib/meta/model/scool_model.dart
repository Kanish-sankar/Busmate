import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolModel {
  String address;
  Timestamp createdAt;
  String email;
  String packageType;
  String password;
  String phoneNumber;
  String schoolId;
  String schoolName;
  String uid;
  Timestamp updatedAt;

  SchoolModel({
    required this.address,
    required this.createdAt,
    required this.email,
    required this.packageType,
    required this.password,
    required this.phoneNumber,
    required this.schoolId,
    required this.schoolName,
    required this.uid,
    required this.updatedAt,
  });

  // Convert Firestore document to SchoolModel
  factory SchoolModel.fromMap(Map<String, dynamic> data) {
    return SchoolModel(
      address: data['address'] ?? '',
      createdAt: data['created_at'] ?? Timestamp.now(),
      email: data['email'] ?? '',
      packageType: data['package_type'] ?? '',
      password: data['password'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      schoolId: data['school_id'] ?? '',
      schoolName: data['school_name'] ?? '',
      uid: data['uid'] ?? '',
      updatedAt: data['updated_at'] ?? Timestamp.now(),
    );
  }

  // Convert SchoolModel to Firestore document (for saving data)
  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'created_at': createdAt,
      'email': email,
      'package_type': packageType,
      'password': password,
      'phone_number': phoneNumber,
      'school_id': schoolId,
      'school_name': schoolName,
      'uid': uid,
      'updated_at': updatedAt,
    };
  }
}
