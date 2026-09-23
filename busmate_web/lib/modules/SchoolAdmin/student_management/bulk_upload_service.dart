import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'student_controller.dart';

class StudentRow {
  final int rowNumber;
  final String name;
  final String rollNumber;
  final String studentClass;
  final String password;
  final String busNumber;
  final String routeName;
  String stopping; // Mutable - auto-corrected to database format
  final String email;
  
  String? busId;          // assignedBusId in Firestore
  String? routeId;        // assignedRouteId in Firestore
  String? routeOriginalName; // assignedRouteName in Firestore (original casing)
  String? driverId;       // assignedDriverId in Firestore
  List<String> errors = [];
  bool isValid = true;

  StudentRow({
    required this.rowNumber,
    required this.name,
    required this.rollNumber,
    required this.studentClass,
    required this.password,
    required this.busNumber,
    required this.routeName,
    required this.stopping,
    required this.email,
  });

  void addError(String error) {
    errors.add(error);
    isValid = false;
  }
}

class BulkUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Parse Excel file and return list of student rows
  Future<List<StudentRow>> parseExcelFile(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      final List<StudentRow> students = [];

      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];

      if (table == null || table.rows.isEmpty) {
        throw Exception('Excel file is empty');
      }

      // Skip header row (row 0), start from row 1
      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        
        // Skip empty rows
        if (row.every((cell) => cell == null || cell.value == null || cell.value.toString().trim().isEmpty)) {
          continue;
        }

        // Extract cell values (8 columns: Name, Roll Number, Class, Password, Bus Number, Route Name, Stopping, Email)
        final name = _getCellValue(row, 0);
        final rollNumber = _getCellValue(row, 1);
        final studentClass = _getCellValue(row, 2);
        final password = _getCellValue(row, 3);
        final busNumber = _getCellValue(row, 4);
        final routeName = _getCellValue(row, 5);
        final stopping = _getCellValue(row, 6);
        final email = _getCellValue(row, 7);

        final studentRow = StudentRow(
          rowNumber: i + 1, // Excel row number (1-indexed, +1 for header)
          name: name,
          rollNumber: rollNumber,
          studentClass: studentClass,
          password: password,
          busNumber: busNumber,
          routeName: routeName,
          stopping: stopping,
          email: email,
        );

        // Basic validation
        if (name.isEmpty) studentRow.addError('Name is required');
        if (rollNumber.isEmpty) studentRow.addError('Roll Number is required');
        if (studentClass.isEmpty) studentRow.addError('Class is required');
        if (password.isEmpty) studentRow.addError('Password is required');
        if (busNumber.isEmpty) studentRow.addError('Bus Number is required');
        if (routeName.isEmpty) studentRow.addError('Route Name is required');
        if (stopping.isEmpty) studentRow.addError('Stopping is required');
        if (email.isEmpty) {
          studentRow.addError('Email is required');
        } else if (!GetUtils.isEmail(email)) {
          studentRow.addError('Invalid email format');
        }

        students.add(studentRow);
      }

      return students;
    } catch (e) {
      throw Exception('Failed to parse Excel file: $e');
    }
  }

  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final cell = row[index];
    if (cell == null || cell.value == null) return '';
    final value = cell.value;
    // IntCellValue: number typed in Excel (e.g. roll number)
    if (value is IntCellValue) {
      return value.value.toString().trim();
    }
    // DoubleCellValue: number with decimals (e.g. 25032006.0 from a numeric password)
    if (value is DoubleCellValue) {
      final d = value.value;
      // Drop .0 for whole numbers so 25032006.0 → "25032006"
      if (d == d.truncateToDouble()) {
        return d.toInt().toString().trim();
      }
      return d.toString().trim();
    }
    // DateCellValue: Excel auto-interpreted a number as a date (e.g. 25/03/2006)
    // We return the raw numeric serial as string so admin knows something is wrong
    if (value is DateCellValue) {
      // e.g. DateCellValue year:2006 month:3 day:25 → "25032006"
      final dt = value.asDateTimeLocal();
      return '${dt.day.toString().padLeft(2,'0')}${dt.month.toString().padLeft(2,'0')}${dt.year}';
    }
    // TextCellValue or anything else
    return value.toString().trim();
  }

  /// Validate students against database (check duplicates, match bus/route/stop)
  Future<void> validateStudents(List<StudentRow> students, String schoolId) async {
    try {
      // Get existing students to check duplicates
      final existingStudents = await _firestore
          .collection('schooldetails')
          .doc(schoolId)
          .collection('students')
          .get();

      final existingEmails = existingStudents.docs
          .map((doc) => (doc.data()['email'] as String?)?.trim().toLowerCase())
          .where((e) => e != null && e.isNotEmpty)
          .toSet();
      final existingRollNumbers = existingStudents.docs
          .map((doc) => (doc.data()['rollNumber'] as String?)?.trim())
          .where((e) => e != null && e.isNotEmpty)
          .toSet();

      // Also check adminusers for email duplicates — filter by schoolId to avoid
      // reading all students from every school (very expensive at scale).
      final existingAdminUsers = await _firestore
          .collection('adminusers')
          .where('role', isEqualTo: 'student')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final existingAdminEmails = existingAdminUsers.docs
          .map((doc) => (doc.data()['email'] as String?)?.trim().toLowerCase())
          .where((e) => e != null && e.isNotEmpty)
          .toSet();
      existingEmails.addAll(existingAdminEmails);

      // Get all buses for matching
      final busesSnapshot = await _firestore
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .get();

      print('🚌 Found ${busesSnapshot.docs.length} buses in database');

      final busMap = <String, Map<String, dynamic>>{};
      for (var doc in busesSnapshot.docs) {
        final busNo = doc.data()['busNo'] as String?;
        if (busNo != null) {
          // Normalize bus number: lowercase and trim for matching
          final normalizedBusNo = busNo.trim().toLowerCase();
          print('  📍 Bus: "$busNo" (normalized: "$normalizedBusNo")');
          busMap[normalizedBusNo] = {
            'id': doc.id,
            'originalBusNo': busNo,
            'routeName': doc.data()['routeName'] as String?,
            'driverId': doc.data()['driverId'] as String?,
          };
        }
      }

      // Get all routes for stop validation
      final routesSnapshot = await _firestore
          .collection('schooldetails')
          .doc(schoolId)
          .collection('routes')
          .get();

      print('🗺️ Found ${routesSnapshot.docs.length} routes in database');

      final routeMap = <String, Map<String, dynamic>>{};
      for (var doc in routesSnapshot.docs) {
        final routeName = doc.data()['routeName'] as String?;
        if (routeName != null) {
          // Get stops from upStops array (each stop is a map with 'name' field)
          final upStops = (doc.data()['upStops'] as List<dynamic>?)
              ?.map((s) => s['name'] as String?)
              .where((s) => s != null)
              .toList() ?? [];
          // Also get stops from downStops array if different
          final downStops = (doc.data()['downStops'] as List<dynamic>?)
              ?.map((s) => s['name'] as String?)
              .where((s) => s != null)
              .toList() ?? [];
          // Combine both lists and remove duplicates
          final allStops = {...upStops, ...downStops}.toList();
          
          // Normalize route name: lowercase and trim for matching
          final normalizedRouteName = routeName.trim().toLowerCase();
          print('  🗺️ Route: "$routeName" (normalized: "$normalizedRouteName") with ${allStops.length} stops (${upStops.length} up + ${downStops.length} down)');
          
          // Create normalized stop map (remove all spaces for flexible matching)
          final normalizedStopMap = <String, String>{}; // normalized -> original
          for (var stop in allStops) {
            final stopStr = stop.toString();
            // Normalize: lowercase, trim, remove ALL spaces
            final normalized = stopStr.trim().toLowerCase().replaceAll(' ', '');
            normalizedStopMap[normalized] = stopStr;
            print('    🚏 Stop: "$stopStr" → normalized: "$normalized"');
          }
          
          // Also read busId from the route doc for cross-validation
          final routeBusId = doc.data()['busId'] as String?;

          routeMap[normalizedRouteName] = {
            'id': doc.id,
            'originalRouteName': routeName,
            'busId': routeBusId, // used to verify this route belongs to the right bus
            'stops': allStops,
            'normalizedStopMap': normalizedStopMap, // Map for flexible matching
          };
        }
      }

      // Check for duplicates within the upload batch
      final uploadEmails = <String>{};
      final uploadRollNumbers = <String>{};

      for (var student in students) {
        // Check email uniqueness (case-insensitive)
        final normalizedEmail = student.email.trim().toLowerCase();
        if (existingEmails.contains(normalizedEmail)) {
          student.addError('Email already exists in database');
        } else if (uploadEmails.contains(normalizedEmail)) {
          student.addError('Duplicate email in upload');
        } else {
          uploadEmails.add(normalizedEmail);
        }

        // Check roll number uniqueness
        final normalizedRollNumber = student.rollNumber.trim();
        if (existingRollNumbers.contains(normalizedRollNumber)) {
          student.addError('Roll number already exists in database');
        } else if (uploadRollNumbers.contains(normalizedRollNumber)) {
          student.addError('Duplicate roll number in upload');
        } else {
          uploadRollNumbers.add(normalizedRollNumber);
        }

        // Match bus number (case-insensitive, trim whitespace)
        final normalizedBusNumber = student.busNumber.trim().toLowerCase();
        if (busMap.containsKey(normalizedBusNumber)) {
          student.busId = busMap[normalizedBusNumber]!['id'];
          student.driverId = busMap[normalizedBusNumber]!['driverId'];
        } else {
          student.addError('Bus number "${student.busNumber}" not found');
        }

        // Match route and validate stop (flexible matching - ignores spaces and case)
        final normalizedRouteName = student.routeName.trim().toLowerCase();
        if (routeMap.containsKey(normalizedRouteName)) {
          student.routeId = routeMap[normalizedRouteName]!['id'];
          student.routeOriginalName = routeMap[normalizedRouteName]!['originalRouteName']; // exact name from DB

          // Cross-check: verify this route actually belongs to the specified bus
          final routeBusId = routeMap[normalizedRouteName]!['busId'] as String?;
          if (student.busId != null && routeBusId != null && routeBusId != student.busId) {
            student.addError('Route "${student.routeName}" does not belong to bus "${student.busNumber}"');
          }
          
          final normalizedStopMap = routeMap[normalizedRouteName]!['normalizedStopMap'] as Map<String, String>;
          // Normalize student's stop: lowercase, trim, remove ALL spaces
          final normalizedStopping = student.stopping.trim().toLowerCase().replaceAll(' ', '');
          
          if (normalizedStopMap.containsKey(normalizedStopping)) {
            // Match found! Use the original stop name from database
            final originalStopName = normalizedStopMap[normalizedStopping]!;
            print('  ✅ Matched stop "${student.stopping}" → "$originalStopName"');
            // Store the original database stop name (not the Excel input)
            student.stopping = originalStopName;
          } else {
            // Show available stops in error message
            final availableStops = normalizedStopMap.values.take(5).join(', ');
            student.addError('Stopping "${student.stopping}" not found in route "${student.routeName}". Available: $availableStops${normalizedStopMap.length > 5 ? '...' : ''}');
          }
        } else {
          student.addError('Route "${student.routeName}" not found');
        }
      }
    } catch (e) {
      throw Exception('Failed to validate students: $e');
    }
  }

  /// Bulk create students in Firebase — optimized for speed.
  ///
  /// Key optimizations vs the old sequential approach:
  ///   1. Single secondary Firebase App (init once, not once-per-student)
  ///   2. Auth creation in parallel batches of 10
  ///   3. All Firestore writes committed in one WriteBatch (or chunks of 500)
  ///   4. Cloud Function calls fired in parallel batches of 20
  ///
  /// Expected timing for 500 students:
  ///   Auth (50 batches × 10 parallel × ~300ms)  →  ~15s
  ///   Firestore WriteBatch (all at once)         →  ~2s
  ///   setUserClaims (25 batches × 20 parallel)   →  ~20s
  ///   Total                                      →  ~40s  (was ~12–17 min)
  Future<Map<String, dynamic>> bulkCreateStudents(
    List<StudentRow> validStudents,
    String schoolId,
    String schoolName,
  ) async {
    final List<String> errors = [];

    final currentAdminUser = FirebaseAuth.instance.currentUser;
    if (currentAdminUser == null) {
      throw Exception('Admin user not logged in');
    }

    print('👤 Current admin: ${currentAdminUser.email}');

    // Filter to only valid students
    final toCreate = validStudents.where((s) => s.isValid).toList();
    final preInvalidCount = validStudents.length - toCreate.length;

    print('📝 Creating ${toCreate.length} student accounts (${preInvalidCount} skipped as invalid)...');

    // ── Step 1: Single secondary app, used for ALL auth creates ──────────────
    final secondaryApp = await Firebase.initializeApp(
      name: 'BulkUploadApp-${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    // Holds successfully created (uid → student) pairs for later Firestore write
    final Map<String, StudentRow> createdStudents = {};

    try {
      // ── Step 2: Auth in parallel batches of 10 ───────────────────────────
      const authBatchSize = 10;
      for (int i = 0; i < toCreate.length; i += authBatchSize) {
        final batch = toCreate.sublist(
          i,
          (i + authBatchSize).clamp(0, toCreate.length),
        );

        final results = await Future.wait(
          batch.map((student) async {
            try {
              final credential = await secondaryAuth.createUserWithEmailAndPassword(
                email: student.email,
                password: student.password,
              );
              final uid = credential.user!.uid;
              print('✅ Auth created: ${student.name} ($uid)');
              return MapEntry(uid, student);
            } catch (e) {
              print('❌ Auth failed: ${student.name} — $e');
              String msg = e.toString();
              if (msg.contains('email-already-in-use')) {
                errors.add('Row ${student.rowNumber} (${student.name}): Email already registered');
              } else if (msg.contains('weak-password')) {
                errors.add('Row ${student.rowNumber} (${student.name}): Password too weak (min 6 characters)');
              } else {
                errors.add('Row ${student.rowNumber} (${student.name}): $e');
              }
              return null;
            }
          }),
        );

        for (final entry in results) {
          if (entry != null) createdStudents[entry.key] = entry.value;
        }

        print('  Auth progress: ${createdStudents.length}/${toCreate.length}');
      }
    } finally {
      // Clean up secondary app — admin session on primary app is untouched
      try {
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      } catch (_) {}
    }

    print('🔐 Auth complete: ${createdStudents.length} accounts created');
    print('👤 Admin still logged in as: ${FirebaseAuth.instance.currentUser?.email}');

    if (createdStudents.isEmpty) {
      return {
        'success': 0,
        'failed': preInvalidCount + toCreate.length,
        'errors': errors,
      };
    }

    // ── Step 3: Firestore WriteBatch — all docs in one round-trip ────────────
    // Firestore batch limit is 500 operations; each student needs 2 writes,
    // so chunk by 250 students per batch.
    const firestoreBatchSize = 250;
    final studentList = createdStudents.entries.toList();

    for (int i = 0; i < studentList.length; i += firestoreBatchSize) {
      final chunk = studentList.sublist(
        i,
        (i + firestoreBatchSize).clamp(0, studentList.length),
      );

      final WriteBatch firestoreBatch = _firestore.batch();

      for (final entry in chunk) {
        final uid = entry.key;
        final student = entry.value;

        // schooldetails/.../students/{uid}
        firestoreBatch.set(
          _firestore.collection('schooldetails').doc(schoolId).collection('students').doc(uid),
          {
            'name': student.name,
            'rollNumber': student.rollNumber,
            'studentClass': student.studentClass,
            'email': student.email,
            'password': '',
            'assignedBusId': student.busId,
            'assignedRouteId': student.routeId,
            'assignedRouteName': student.routeOriginalName,
            'assignedDriverId': student.driverId,
            'stopping': student.stopping,
            'parentContact': '',
            'notificationType': 'Voice Notification',
            'languagePreference': 'English',
            'notificationPreferenceByTime': 30,
            'notificationPreferenceByLocation': '',
            'notified': false,
            'schoolId': schoolId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // adminusers/{uid}
        firestoreBatch.set(
          _firestore.collection('adminusers').doc(uid),
          {
            'role': 'student',
            'schoolId': schoolId,
            'studentId': uid,
            'name': student.name,
            'email': student.email,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }

      try {
        await firestoreBatch.commit();
        print('✅ Firestore batch committed: ${chunk.length} students (chunk ${i ~/ firestoreBatchSize + 1})');
      } catch (e) {
        // If a batch fails, mark all students in this chunk as failed
        for (final entry in chunk) {
          errors.add('Row ${entry.value.rowNumber} (${entry.value.name}): Firestore write failed — $e');
          createdStudents.remove(entry.key);
        }
      }
    }

    // ── Step 4: Cloud Function setUserClaims — parallel batches of 20 ────────
    final callable = FirebaseFunctions.instance.httpsCallable('setUserClaims');
    const claimsBatchSize = 20;
    final uidList = createdStudents.keys.toList();

    for (int i = 0; i < uidList.length; i += claimsBatchSize) {
      final chunk = uidList.sublist(
        i,
        (i + claimsBatchSize).clamp(0, uidList.length),
      );

      await Future.wait(
        chunk.map((uid) async {
          try {
            await callable.call({'uid': uid});
          } catch (e) {
            print('⚠️ Custom claims failed for $uid (non-critical): $e');
          }
        }),
      );

      print('  Claims progress: ${(i + chunk.length).clamp(0, uidList.length)}/${uidList.length}');
    }

    final successCount = createdStudents.length;
    final failCount = preInvalidCount + (toCreate.length - successCount);

    print('🎉 Bulk import complete: $successCount success, $failCount failed');
    print('👤 Admin still logged in as: ${FirebaseAuth.instance.currentUser?.email}');

    return {
      'success': successCount,
      'failed': failCount,
      'errors': errors,
    };
  }
}
