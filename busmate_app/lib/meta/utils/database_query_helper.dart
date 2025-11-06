import 'package:get/get.dart';
import 'package:busmate/meta/utils/cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaginatedQuery {
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  int pageSize;
  
  PaginatedQuery({this.pageSize = 20});
  
  void reset() {
    lastDocument = null;
    hasMore = true;
  }
}

class DatabaseQueryHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Paginated query for students
  static Future<Map<String, dynamic>> getStudentsPaginated({
    required String schoolId,
    String? busId,
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Create cache key
      String cacheKey = 'students_${schoolId}_${busId ?? 'all'}_${lastDocument?.id ?? 'first'}_$pageSize';
      
      // Try to get from cache first
      Map<String, dynamic>? cachedResult = await CacheManager.getCached<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
      
      Query query = _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('studentName')
          .limit(pageSize + 1); // Get one extra to check if there are more
      
      if (busId != null) {
        query = query.where('busId', isEqualTo: busId);
      }
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = snapshot.docs;
      bool hasMore = documents.length > pageSize;
      
      if (hasMore) {
        documents.removeLast(); // Remove the extra document
      }
      
      List<Map<String, dynamic>> students = documents.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      Map<String, dynamic> result = {
        'students': students,
        'hasMore': hasMore,
        'lastDocument': documents.isNotEmpty ? documents.last : null,
      };
      
      // Cache the result for 5 minutes
      await CacheManager.setCached(cacheKey, result, ttl: Duration(minutes: 5));
      
      return result;
      
    } catch (e) {
      print('Error getting paginated students: $e');
      throw e;
    }
  }
  
  // Paginated query for bus status
  static Future<Map<String, dynamic>> getBusStatusPaginated({
    required String schoolId,
    bool? isActive,
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      String cacheKey = 'bus_status_${schoolId}_${isActive?.toString() ?? 'all'}_${lastDocument?.id ?? 'first'}_$pageSize';
      
      Map<String, dynamic>? cachedResult = await CacheManager.getCached<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
      
      Query query = _firestore
          .collection('bus_status')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('busNumber')
          .limit(pageSize + 1);
      
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = snapshot.docs;
      bool hasMore = documents.length > pageSize;
      
      if (hasMore) {
        documents.removeLast();
      }
      
      List<Map<String, dynamic>> busStatus = documents.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      Map<String, dynamic> result = {
        'busStatus': busStatus,
        'hasMore': hasMore,
        'lastDocument': documents.isNotEmpty ? documents.last : null,
      };
      
      await CacheManager.setCached(cacheKey, result, ttl: Duration(minutes: 3));
      
      return result;
      
    } catch (e) {
      print('Error getting paginated bus status: $e');
      throw e;
    }
  }
  
  // Paginated query for notifications
  static Future<Map<String, dynamic>> getNotificationsPaginated({
    String? schoolId,
    List<String>? recipientGroups,
    int pageSize = 15,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      String cacheKey = 'notifications_${schoolId ?? 'all'}_${recipientGroups?.join('_') ?? 'all'}_${lastDocument?.id ?? 'first'}_$pageSize';
      
      Map<String, dynamic>? cachedResult = await CacheManager.getCached<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
      
      Query query = _firestore
          .collection('notifications')
          .orderBy('sentAt', descending: true)
          .limit(pageSize + 1);
      
      if (schoolId != null) {
        query = query.where('schoolIds', arrayContains: schoolId);
      }
      
      if (recipientGroups != null && recipientGroups.isNotEmpty) {
        query = query.where('recipientGroups', arrayContainsAny: recipientGroups);
      }
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = snapshot.docs;
      bool hasMore = documents.length > pageSize;
      
      if (hasMore) {
        documents.removeLast();
      }
      
      List<Map<String, dynamic>> notifications = documents.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      Map<String, dynamic> result = {
        'notifications': notifications,
        'hasMore': hasMore,
        'lastDocument': documents.isNotEmpty ? documents.last : null,
      };
      
      await CacheManager.setCached(cacheKey, result, ttl: Duration(minutes: 2));
      
      return result;
      
    } catch (e) {
      print('Error getting paginated notifications: $e');
      throw e;
    }
  }
  
  // Optimized query for payment records with pagination
  static Future<Map<String, dynamic>> getPaymentsPaginated({
    required String schoolId,
    String? studentId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int pageSize = 25,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      String cacheKey = 'payments_${schoolId}_${studentId ?? 'all'}_${status ?? 'all'}_${lastDocument?.id ?? 'first'}_$pageSize';
      
      Map<String, dynamic>? cachedResult = await CacheManager.getCached<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
      
      Query query = _firestore
          .collection('payment')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('paymentDate', descending: true)
          .limit(pageSize + 1);
      
      if (studentId != null) {
        query = query.where('studentId', isEqualTo: studentId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      
      if (fromDate != null) {
        query = query.where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
      }
      
      if (toDate != null) {
        query = query.where('paymentDate', isLessThanOrEqualTo: Timestamp.fromDate(toDate));
      }
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = snapshot.docs;
      bool hasMore = documents.length > pageSize;
      
      if (hasMore) {
        documents.removeLast();
      }
      
      List<Map<String, dynamic>> payments = documents.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      Map<String, dynamic> result = {
        'payments': payments,
        'hasMore': hasMore,
        'lastDocument': documents.isNotEmpty ? documents.last : null,
      };
      
      await CacheManager.setCached(cacheKey, result, ttl: Duration(minutes: 10));
      
      return result;
      
    } catch (e) {
      print('Error getting paginated payments: $e');
      throw e;
    }
  }
  
  // Optimized search with pagination
  static Future<Map<String, dynamic>> searchStudents({
    required String schoolId,
    required String searchTerm,
    int pageSize = 15,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      if (searchTerm.isEmpty) {
        return {'students': [], 'hasMore': false, 'lastDocument': null};
      }
      
      String searchLower = searchTerm.toLowerCase();
      String searchUpper = searchLower.substring(0, searchLower.length - 1) + 
          String.fromCharCode(searchLower.codeUnitAt(searchLower.length - 1) + 1);
      
      Query query = _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .where('studentNameLower', isGreaterThanOrEqualTo: searchLower)
          .where('studentNameLower', isLessThan: searchUpper)
          .orderBy('studentNameLower')
          .limit(pageSize + 1);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      QuerySnapshot snapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = snapshot.docs;
      bool hasMore = documents.length > pageSize;
      
      if (hasMore) {
        documents.removeLast();
      }
      
      List<Map<String, dynamic>> students = documents.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
      
      return {
        'students': students,
        'hasMore': hasMore,
        'lastDocument': documents.isNotEmpty ? documents.last : null,
      };
      
    } catch (e) {
      print('Error searching students: $e');
      throw e;
    }
  }
  
  // Batch operations for bulk updates
  static Future<void> batchUpdateStudents(List<Map<String, dynamic>> updates) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (Map<String, dynamic> update in updates) {
        String studentId = update['id'];
        Map<String, dynamic> data = Map.from(update);
        data.remove('id');
        
        DocumentReference studentRef = _firestore.collection('students').doc(studentId);
        batch.update(studentRef, data);
      }
      
      await batch.commit();
      
      // Clear related cache entries
      await CacheManager.clearByPattern('students_');
      
    } catch (e) {
      print('Error in batch update students: $e');
      throw e;
    }
  }
  
  // Optimized query for dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats(String schoolId) async {
    try {
      String cacheKey = 'dashboard_stats_$schoolId';
      
      Map<String, dynamic>? cachedStats = await CacheManager.getCached<Map<String, dynamic>>(cacheKey);
      if (cachedStats != null) {
        return cachedStats;
      }
      
      // Run multiple queries in parallel
      List<Future> futures = [
        _firestore.collection('students').where('schoolId', isEqualTo: schoolId).count().get(),
        _firestore.collection('bus_status').where('schoolId', isEqualTo: schoolId).where('isActive', isEqualTo: true).count().get(),
        _firestore.collection('payment').where('schoolId', isEqualTo: schoolId).where('status', isEqualTo: 'pending').count().get(),
        _firestore.collection('notifications').where('schoolIds', arrayContains: schoolId).orderBy('sentAt', descending: true).limit(5).get(),
      ];
      
      List results = await Future.wait(futures);
      
      Map<String, dynamic> stats = {
        'totalStudents': results[0].count,
        'activeBuses': results[1].count,
        'pendingPayments': results[2].count,
        'recentNotifications': results[3].docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        }).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      // Cache for 5 minutes
      await CacheManager.setCached(cacheKey, stats, ttl: Duration(minutes: 5));
      
      return stats;
      
    } catch (e) {
      print('Error getting dashboard stats: $e');
      throw e;
    }
  }
  
  // Clear cache for specific patterns
  static Future<void> clearCacheForSchool(String schoolId) async {
    await CacheManager.clearByPattern('students_$schoolId');
    await CacheManager.clearByPattern('bus_status_$schoolId');
    await CacheManager.clearByPattern('payments_$schoolId');
    await CacheManager.clearByPattern('dashboard_stats_$schoolId');
  }
  
  // Cleanup old data
  static Future<void> cleanupOldData() async {
    try {
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: 90));
      
      // Delete old notifications
      QuerySnapshot oldNotifications = await _firestore
          .collection('notifications')
          .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(100)
          .get();
      
      if (oldNotifications.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (DocumentSnapshot doc in oldNotifications.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      print('Cleaned up ${oldNotifications.docs.length} old notifications');
      
    } catch (e) {
      print('Error cleaning up old data: $e');
    }
  }
}

// Extension for GetX controllers to use paginated queries
mixin PaginationMixin on GetxController {
  final Map<String, PaginatedQuery> _paginatedQueries = {};
  
  PaginatedQuery getPaginatedQuery(String key, {int pageSize = 20}) {
    if (!_paginatedQueries.containsKey(key)) {
      _paginatedQueries[key] = PaginatedQuery(pageSize: pageSize);
    }
    return _paginatedQueries[key]!;
  }
  
  void resetPagination(String key) {
    _paginatedQueries[key]?.reset();
  }
  
  @override
  void onClose() {
    _paginatedQueries.clear();
    super.onClose();
  }
}