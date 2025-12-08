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
      createdAt: data['created_at'] ?? data['createdAt'] ?? Timestamp.now(),
      email: data['email'] ?? '',
      packageType: data['package_type'] ?? data['packageType'] ?? '',
      password: data['password'] ?? '',
      phoneNumber: data['phone_number'] ?? data['phone'] ?? '',
      schoolId: data['school_id'] ?? data['schoolId'] ?? '',
      schoolName: data['school_name'] ?? data['schoolName'] ?? '',
      uid: data['uid'] ?? '',
      updatedAt: data['updated_at'] ?? data['updatedAt'] ?? Timestamp.now(),
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

  // Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'created_at': createdAt.millisecondsSinceEpoch,
      'email': email,
      'package_type': packageType,
      'password': password,
      'phone_number': phoneNumber,
      'school_id': schoolId,
      'school_name': schoolName,
      'uid': uid,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from JSON (for cache retrieval)
  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      address: json['address'] ?? '',
      createdAt: json['created_at'] is int 
          ? Timestamp.fromMillisecondsSinceEpoch(json['created_at']) 
          : Timestamp.now(),
      email: json['email'] ?? '',
      packageType: json['package_type'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      schoolId: json['school_id'] ?? '',
      schoolName: json['school_name'] ?? '',
      uid: json['uid'] ?? '',
      updatedAt: json['updated_at'] is int 
          ? Timestamp.fromMillisecondsSinceEpoch(json['updated_at']) 
          : Timestamp.now(),
    );
  }
}
