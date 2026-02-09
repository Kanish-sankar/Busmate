// File: lib/modules/SuperAdmin/school_management/school_management_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class SchoolManagementController extends GetxController {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  var schools = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasMoreData = true.obs;
  var isSearching = false.obs;
  
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 50;
  String _currentSearchQuery = '';

  @override
  void onInit() {
    super.onInit();
    fetchSchools();
  }

  // Initial fetch with pagination support
  void fetchSchools() async {
    try {
      isLoading.value = true;
      _lastDocument = null;
      hasMoreData.value = true;
      
      QuerySnapshot snapshot = await firestore
          .collection('schooldetails')
          .limit(_pageSize)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        schools.value = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['school_id'] = doc.id;
          return data;
        }).toList();
        
        hasMoreData.value = snapshot.docs.length == _pageSize;
      } else {
        schools.value = [];
        hasMoreData.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Unable to load schools. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }

  // Load more schools (infinite scroll)
  Future<void> loadMoreSchools() async {
    if (isLoadingMore.value || !hasMoreData.value || isSearching.value) return;
    
    try {
      isLoadingMore.value = true;
      
      QuerySnapshot snapshot = await firestore
          .collection('schooldetails')
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final newSchools = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['school_id'] = doc.id;
          return data;
        }).toList();
        
        schools.addAll(newSchools);
        hasMoreData.value = snapshot.docs.length == _pageSize;
      } else {
        hasMoreData.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Unable to load more schools.");
    } finally {
      isLoadingMore.value = false;
    }
  }

  // Optimized server-side search - only reads matching documents
  void searchSchools(String query) async {
    _currentSearchQuery = query;
    
    if (query.isEmpty) {
      isSearching.value = false;
      fetchSchools(); // Reset to paginated view
      return;
    }

    // If we have fewer than 100 schools loaded, search in memory (0 cost)
    if (schools.length < 100 && !isSearching.value) {
      _searchInLoadedData(query);
      return;
    }

    try {
      isSearching.value = true;
      isLoading.value = true;
      
      final queryLowerCase = query.toLowerCase();
      final queryUpperCase = query.toUpperCase();
      
      // Firestore range query - only reads documents that match
      // Uses schoolName field with range query for prefix matching
      QuerySnapshot snapshot = await firestore
          .collection('schooldetails')
          .where('schoolName', isGreaterThanOrEqualTo: query)
          .where('schoolName', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(50) // Limit search results
          .get();
      
      // Also search with lowercase
      QuerySnapshot snapshotLower = await firestore
          .collection('schooldetails')
          .where('schoolName', isGreaterThanOrEqualTo: queryLowerCase)
          .where('schoolName', isLessThanOrEqualTo: queryLowerCase + '\uf8ff')
          .limit(50)
          .get();
      
      // Also search with uppercase
      QuerySnapshot snapshotUpper = await firestore
          .collection('schooldetails')
          .where('schoolName', isGreaterThanOrEqualTo: queryUpperCase)
          .where('schoolName', isLessThanOrEqualTo: queryUpperCase + '\uf8ff')
          .limit(50)
          .get();
      
      // Combine results and remove duplicates
      final allDocs = <String, DocumentSnapshot>{};
      for (var doc in snapshot.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snapshotLower.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in snapshotUpper.docs) {
        allDocs[doc.id] = doc;
      }
      
      // Convert to list and apply additional client-side filtering
      final results = allDocs.values.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final schoolName = (data['schoolName'] ?? data['school_name'] ?? '').toString().toLowerCase();
        final schoolId = (data['schoolId'] ?? data['school_id'] ?? '').toString().toLowerCase();
        final address = (data['address'] ?? '').toString().toLowerCase();
        
        return schoolName.contains(queryLowerCase) ||
               schoolId.contains(queryLowerCase) ||
               address.contains(queryLowerCase);
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['school_id'] = doc.id;
        return data;
      }).toList();
      
      schools.value = results;
      hasMoreData.value = false; // Disable pagination during search
    } catch (e) {
      // If Firestore query fails (no index), fall back to in-memory search
      if (schools.isNotEmpty) {
        _searchInLoadedData(query);
      } else {
        Get.snackbar("Error", "Search failed. Please try again.");
      }
    } finally {
      isLoading.value = false;
    }
  }
  
  // Search in already-loaded data (0 Firestore reads)
  void _searchInLoadedData(String query) {
    isSearching.value = true;
    final queryLowerCase = query.toLowerCase();
    
    final results = schools.where((school) {
      final schoolName = (school['schoolName'] ?? school['school_name'] ?? '').toString().toLowerCase();
      final schoolId = (school['schoolId'] ?? school['school_id'] ?? '').toString().toLowerCase();
      final address = (school['address'] ?? '').toString().toLowerCase();
      
      return schoolName.contains(queryLowerCase) ||
             schoolId.contains(queryLowerCase) ||
             address.contains(queryLowerCase);
    }).toList();
    
    schools.value = results;
    hasMoreData.value = false;
  }

  void clearSearch() {
    _currentSearchQuery = '';
    isSearching.value = false;
    fetchSchools();
  }

  Future<void> deleteSchoolAndAllData(String schoolId) async {
    try {
      isLoading.value = true;
      final firestore = FirebaseFirestore.instance;

      // 1. Delete subcollections under schools/{schoolId}
      final subcollections = [
        'buses',
        'drivers',
        'students',
        'payments',
        'admins'
      ];
      for (final sub in subcollections) {
        final subColRef =
            firestore.collection('schools').doc(schoolId).collection(sub);
        final subDocs = await subColRef.get();
        for (final doc in subDocs.docs) {
          await doc.reference.delete();
        }
      }

      // 2. Delete students in root students collection with schoolId
      final studentsSnap = await firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      for (final doc in studentsSnap.docs) {
        await doc.reference.delete();
      }

      // 3. Delete drivers in root drivers collection with schoolId
      final driversSnap = await firestore
          .collection('drivers')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      for (final doc in driversSnap.docs) {
        await doc.reference.delete();
      }

      // 4. Delete the school document itself
      await firestore.collection('schools').doc(schoolId).delete();

      // 5. Optionally, remove from local list
      schools.removeWhere((s) => s['school_id'] == schoolId);

      Get.snackbar("Success", "School and all related data deleted.");
      fetchSchools();
    } catch (e) {
      Get.snackbar("Error", "Unable to delete school. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }
}
