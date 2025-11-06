import 'dart:convert';
import 'dart:developer';
import 'dart:html' as html;

/// Web-specific cache manager using localStorage
class WebCacheManager {
  static const String _prefix = 'busmate_web_';
  
  /// Store data in localStorage with expiration
  static void set(String key, dynamic data, {Duration? ttl}) {
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': ttl?.inMilliseconds,
      };
      
      html.window.localStorage['$_prefix$key'] = jsonEncode(cacheData);
      log('📦 Cached data for key: $key');
    } catch (e) {
      log('❌ Error caching data for key $key: $e');
    }
  }
  
  /// Get data from localStorage with TTL check
  static T? get<T>(String key) {
    try {
      final cachedString = html.window.localStorage['$_prefix$key'];
      if (cachedString == null) return null;
      
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final ttl = cacheData['ttl'] as int?;
      
      // Check if expired
      if (ttl != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > ttl) {
          remove(key);
          log('🗑️ Cache expired for key: $key');
          return null;
        }
      }
      
      log('📦 Retrieved cached data for key: $key');
      return cacheData['data'] as T;
    } catch (e) {
      log('❌ Error retrieving cache for key $key: $e');
      return null;
    }
  }
  
  /// Remove specific cache entry
  static void remove(String key) {
    html.window.localStorage.remove('$_prefix$key');
    log('🗑️ Removed cache for key: $key');
  }
  
  /// Clear all app cache
  static void clearAll() {
    final keys = html.window.localStorage.keys
        .where((key) => key.startsWith(_prefix))
        .toList();
    
    for (final key in keys) {
      html.window.localStorage.remove(key);
    }
    
    log('🗑️ Cleared all cache (${keys.length} entries)');
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getStats() {
    final keys = html.window.localStorage.keys
        .where((key) => key.startsWith(_prefix));
    
    int totalEntries = keys.length;
    int expiredEntries = 0;
    int totalSize = 0;
    
    for (final key in keys) {
      final value = html.window.localStorage[key];
      if (value != null) {
        totalSize += value.length;
        
        try {
          final cacheData = jsonDecode(value) as Map<String, dynamic>;
          final timestamp = cacheData['timestamp'] as int;
          final ttl = cacheData['ttl'] as int?;
          
          if (ttl != null) {
            final age = DateTime.now().millisecondsSinceEpoch - timestamp;
            if (age > ttl) {
              expiredEntries++;
            }
          }
        } catch (e) {
          // Invalid cache entry
          expiredEntries++;
        }
      }
    }
    
    return {
      'totalEntries': totalEntries,
      'expiredEntries': expiredEntries,
      'totalSizeBytes': totalSize,
      'totalSizeKB': (totalSize / 1024).toStringAsFixed(2),
    };
  }
  
  /// Clean up expired entries
  static void cleanupExpired() {
    final keys = html.window.localStorage.keys
        .where((key) => key.startsWith(_prefix))
        .toList();
    
    int cleanedCount = 0;
    
    for (final key in keys) {
      final value = html.window.localStorage[key];
      if (value != null) {
        try {
          final cacheData = jsonDecode(value) as Map<String, dynamic>;
          final timestamp = cacheData['timestamp'] as int;
          final ttl = cacheData['ttl'] as int?;
          
          if (ttl != null) {
            final age = DateTime.now().millisecondsSinceEpoch - timestamp;
            if (age > ttl) {
              html.window.localStorage.remove(key);
              cleanedCount++;
            }
          }
        } catch (e) {
          // Remove invalid entries
          html.window.localStorage.remove(key);
          cleanedCount++;
        }
      }
    }
    
    if (cleanedCount > 0) {
      log('🧹 Cleaned up $cleanedCount expired cache entries');
    }
  }
  
  /// Cache user data
  static void cacheUserData(String userId, Map<String, dynamic> userData) {
    set('user_$userId', userData, ttl: const Duration(hours: 24));
  }
  
  /// Get cached user data
  static Map<String, dynamic>? getCachedUserData(String userId) {
    return get<Map<String, dynamic>>('user_$userId');
  }
  
  /// Cache school data
  static void cacheSchoolData(String schoolId, Map<String, dynamic> schoolData) {
    set('school_$schoolId', schoolData, ttl: const Duration(hours: 12));
  }
  
  /// Get cached school data
  static Map<String, dynamic>? getCachedSchoolData(String schoolId) {
    return get<Map<String, dynamic>>('school_$schoolId');
  }
  
  /// Cache dashboard stats
  static void cacheDashboardStats(String adminId, Map<String, dynamic> stats) {
    set('dashboard_stats_$adminId', stats, ttl: const Duration(minutes: 15));
  }
  
  /// Get cached dashboard stats
  static Map<String, dynamic>? getCachedDashboardStats(String adminId) {
    return get<Map<String, dynamic>>('dashboard_stats_$adminId');
  }
  
  /// Cache list data with pagination info
  static void cacheListData(
    String listKey, 
    List<dynamic> data, 
    {int? totalCount, int? currentPage}
  ) {
    final cacheData = {
      'data': data,
      'totalCount': totalCount,
      'currentPage': currentPage,
      'cached_at': DateTime.now().toIso8601String(),
    };
    set(listKey, cacheData, ttl: const Duration(minutes: 10));
  }
  
  /// Get cached list data
  static Map<String, dynamic>? getCachedListData(String listKey) {
    return get<Map<String, dynamic>>(listKey);
  }
}