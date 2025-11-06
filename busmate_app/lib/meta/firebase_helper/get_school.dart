import 'dart:developer';

import 'package:busmate/meta/model/scool_model.dart';
import 'package:busmate/meta/utils/cache_manager.dart';
import 'package:busmate/meta/utils/database_query_helper.dart';
import 'package:busmate/meta/utils/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class GetSchools extends GetxController with PaginationMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  RxList<SchoolModel> schoolList = <SchoolModel>[].obs;
  var isLoading = true.obs;
  var hasMoreSchools = true.obs;
  
  static const String _cacheKey = 'schools_list';
  static const int _pageSize = 20;

  @override
  void onInit() {
    fetchSchools();
    super.onInit();
  }

  // Optimized fetch with caching, pagination, and error handling
  void fetchSchools({bool forceRefresh = false, bool loadMore = false}) async {
    try {
      if (!loadMore) {
        isLoading(true);
        resetPagination('schools');
      }
      
      // Try to get data from cache first (only for initial load)
      if (!forceRefresh && !loadMore) {
        final cachedData = await CacheManager.getCached<List<dynamic>>(_cacheKey);
        if (cachedData != null) {
          log('📦 Loading schools from cache');
          List<SchoolModel> schools = cachedData.map((data) {
            return SchoolModel.fromMap(Map<String, dynamic>.from(data));
          }).toList();
          
          schoolList.assignAll(schools);
          isLoading(false);
          return;
        }
      }
      
      log('🌐 Fetching schools from Firestore');
      
      // Use paginated query for better performance
      PaginatedQuery paginatedQuery = getPaginatedQuery('schools', pageSize: _pageSize);
      
      Query query = firestore
        .collection('schools')
        .where('isActive', isEqualTo: true) // Only fetch active schools
        .orderBy('school_name')
        .limit(_pageSize + 1); // Get one extra to check if there are more
      
      if (loadMore && paginatedQuery.lastDocument != null) {
        query = query.startAfterDocument(paginatedQuery.lastDocument!);
      }
      
      QuerySnapshot querySnapshot = await query.get();
      
      List<QueryDocumentSnapshot> documents = querySnapshot.docs;
      bool hasMore = documents.length > _pageSize;
      
      if (hasMore) {
        documents.removeLast(); // Remove the extra document
        paginatedQuery.lastDocument = documents.last;
      } else {
        paginatedQuery.hasMore = false;
      }
      
      hasMoreSchools.value = hasMore;

      List<SchoolModel> schools = documents.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return SchoolModel.fromMap(data);
      }).toList();

      if (loadMore) {
        schoolList.addAll(schools);
      } else {
        schoolList.assignAll(schools);
        
        // Cache the schools list (only for initial load)
        List<Map<String, dynamic>> schoolsData = schools.map((school) {
          return school.toMap();
        }).toList();
        
        await CacheManager.setCached(_cacheKey, schoolsData, 
          ttl: const Duration(hours: 2));
      }
      
      log('✅ Loaded ${schools.length} schools successfully${loadMore ? ' (load more)' : ''}');
      
    } catch (e) {
      log('❌ Error fetching schools: $e');
      ErrorHandler.logError(e, context: 'Failed to load schools');
      ErrorHandler.showErrorSnackbar(
        'Failed to load schools. Please try again.',
        context: 'GetSchools.fetchSchools',
      );
    } finally {
      if (!loadMore) {
        isLoading(false);
      }
    }
  }
  
  void loadMoreSchools() {
    if (hasMoreSchools.value && !isLoading.value) {
      fetchSchools(loadMore: true);
    }
  }
  
  void refreshSchools() {
    resetPagination('schools');
    hasMoreSchools.value = true;
    fetchSchools(forceRefresh: true);
  }
  
  // Search schools by name with optimization
  void searchSchools(String searchTerm) async {
    try {
      if (searchTerm.isEmpty) {
        refreshSchools();
        return;
      }
      
      isLoading(true);
      
      String searchLower = searchTerm.toLowerCase();
      String searchUpper = searchLower.substring(0, searchLower.length - 1) + 
          String.fromCharCode(searchLower.codeUnitAt(searchLower.length - 1) + 1);
      
      QuerySnapshot querySnapshot = await firestore
        .collection('schools')
        .where('isActive', isEqualTo: true)
        .where('school_name_lower', isGreaterThanOrEqualTo: searchLower)
        .where('school_name_lower', isLessThan: searchUpper)
        .orderBy('school_name_lower')
        .limit(50)
        .get();

      List<SchoolModel> schools = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return SchoolModel.fromMap(data);
      }).toList();

      schoolList.assignAll(schools);
      hasMoreSchools.value = false; // No pagination for search results
      
    } catch (e) {
      log('❌ Error searching schools: $e');
      ErrorHandler.logError(e, context: 'Failed to search schools');
      ErrorHandler.showErrorSnackbar(
        'Failed to search schools. Please try again.',
        context: 'GetSchools.searchSchools',
      );
    } finally {
      isLoading(false);
    }
  }
}

