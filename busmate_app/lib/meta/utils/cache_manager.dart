import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'dart:developer';

/// Centralized cache management system for BusMate app
/// Implements multi-level caching with TTL (Time To Live) support
class CacheManager {
  static final GetStorage _storage = GetStorage();
  
  // Cache durations for different data types
  static const Duration _shortCacheDuration = Duration(minutes: 5);
  static const Duration _mediumCacheDuration = Duration(hours: 1);
  static const Duration _longCacheDuration = Duration(hours: 24);
  
  // Cache keys
  static const String _cachePrefix = 'busmate_cache_';
  static const String _studentDataKey = '${_cachePrefix}student_data';
  static const String _schoolDataKey = '${_cachePrefix}school_data';
  static const String _busDataKey = '${_cachePrefix}bus_data';
  // Driver data key removed as unused
  static const String _routeDataKey = '${_cachePrefix}route_data';
  
  /// Generic method to get cached data with TTL check
  static Future<T?> getCached<T>(
    String key, {
    Duration? ttl,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final cachedData = _storage.read(key);
      if (cachedData == null) return null;
      
      final Map<String, dynamic> cacheEntry = Map<String, dynamic>.from(cachedData);
      final DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
      final Duration cacheTTL = ttl ?? _mediumCacheDuration;
      
      // Check if cache is expired
      if (DateTime.now().difference(cacheTime) > cacheTTL) {
        await _storage.remove(key);
        log('Cache expired for key: $key');
        return null;
      }
      
      // Return cached data
      if (fromJson != null) {
        return fromJson(cacheEntry['data']);
      }
      return cacheEntry['data'] as T;
    } catch (e) {
      log('Error reading cache for key $key: $e');
      return null;
    }
  }
  
  /// Generic method to set cached data with timestamp
  static Future<void> setCached<T>(
    String key,
    T data, {
    Duration? ttl,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    try {
      final cacheEntry = {
        'data': toJson != null ? toJson(data) : data,
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': (ttl ?? _mediumCacheDuration).inMilliseconds,
      };
      
      await _storage.write(key, cacheEntry);
      log('Data cached for key: $key');
    } catch (e) {
      log('Error writing cache for key $key: $e');
    }
  }
  
  /// Clear specific cache entry
  static Future<void> clearCache(String key) async {
    await _storage.remove(key);
    log('Cache cleared for key: $key');
  }
  
  /// Clear all app cache
  static Future<void> clearAllCache() async {
    final keys = _storage.getKeys().where((key) => key.startsWith(_cachePrefix));
    for (final key in keys) {
      await _storage.remove(key);
    }
    log('All cache cleared');
  }
  
  /// Clear cache entries matching a pattern
  static Future<void> clearByPattern(String pattern) async {
    final keys = _storage.getKeys().where((key) => key.contains(pattern));
    for (final key in keys) {
      await _storage.remove(key);
    }
    log('Cache cleared for pattern: $pattern (${keys.length} entries)');
  }
  
  /// Get cache size and statistics
  static Map<String, dynamic> getCacheStats() {
    final keys = _storage.getKeys().where((key) => key.startsWith(_cachePrefix));
    int totalSize = 0;
    int expiredCount = 0;
    
    for (final key in keys) {
      try {
        final cachedData = _storage.read(key);
        if (cachedData != null) {
          totalSize += jsonEncode(cachedData).length;
          
          final Map<String, dynamic> cacheEntry = Map<String, dynamic>.from(cachedData);
          final DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
          final int ttlMs = cacheEntry['ttl'] ?? _mediumCacheDuration.inMilliseconds;
          
          if (DateTime.now().difference(cacheTime).inMilliseconds > ttlMs) {
            expiredCount++;
          }
        }
      } catch (e) {
        log('Error reading cache stats for key $key: $e');
      }
    }
    
    return {
      'totalEntries': keys.length,
      'totalSizeBytes': totalSize,
      'expiredEntries': expiredCount,
    };
  }
  
  /// Cleanup expired cache entries
  static Future<void> cleanupExpiredCache() async {
    final keys = _storage.getKeys().where((key) => key.startsWith(_cachePrefix));
    int cleanedCount = 0;
    
    for (final key in keys) {
      try {
        final cachedData = _storage.read(key);
        if (cachedData != null) {
          final Map<String, dynamic> cacheEntry = Map<String, dynamic>.from(cachedData);
          final DateTime cacheTime = DateTime.parse(cacheEntry['timestamp']);
          final int ttlMs = cacheEntry['ttl'] ?? _mediumCacheDuration.inMilliseconds;
          
          if (DateTime.now().difference(cacheTime).inMilliseconds > ttlMs) {
            await _storage.remove(key);
            cleanedCount++;
          }
        }
      } catch (e) {
        log('Error cleaning cache for key $key: $e');
      }
    }
    
    log('Cleaned up $cleanedCount expired cache entries');
  }
  
  // Specific cache methods for different data types
  
  /// Cache student data
  static Future<void> cacheStudentData(String studentId, Map<String, dynamic> data) async {
    await setCached('${_studentDataKey}_$studentId', data, ttl: _longCacheDuration);
  }
  
  /// Get cached student data
  static Future<Map<String, dynamic>?> getCachedStudentData(String studentId) async {
    return await getCached('${_studentDataKey}_$studentId', ttl: _longCacheDuration);
  }
  
  /// Cache school data
  static Future<void> cacheSchoolData(String schoolId, Map<String, dynamic> data) async {
    await setCached('${_schoolDataKey}_$schoolId', data, ttl: _longCacheDuration);
  }
  
  /// Get cached school data
  static Future<Map<String, dynamic>?> getCachedSchoolData(String schoolId) async {
    return await getCached('${_schoolDataKey}_$schoolId', ttl: _longCacheDuration);
  }
  
  /// Cache bus status (short-lived for real-time data)
  static Future<void> cacheBusStatus(String busId, Map<String, dynamic> data) async {
    await setCached('${_busDataKey}_status_$busId', data, ttl: _shortCacheDuration);
  }
  
  /// Get cached bus status
  static Future<Map<String, dynamic>?> getCachedBusStatus(String busId) async {
    return await getCached('${_busDataKey}_status_$busId', ttl: _shortCacheDuration);
  }
  
  /// Cache route data
  static Future<void> cacheRouteData(String routeId, Map<String, dynamic> data) async {
    await setCached('${_routeDataKey}_$routeId', data, ttl: _longCacheDuration);
  }
  
  /// Get cached route data
  static Future<Map<String, dynamic>?> getCachedRouteData(String routeId) async {
    return await getCached('${_routeDataKey}_$routeId', ttl: _longCacheDuration);
  }
  
  /// Initialize cache manager
  static Future<void> initialize() async {
    await GetStorage.init();
    
    // Clean up expired cache on startup
    await cleanupExpiredCache();
    
    log('CacheManager initialized');
  }
}