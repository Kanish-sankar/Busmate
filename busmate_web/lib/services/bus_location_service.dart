import 'package:firebase_database/firebase_database.dart';
import 'package:busmate_web/models/bus_location.dart';

/// Service to handle real-time bus location updates using Firebase Realtime Database
class BusLocationService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Get reference to bus locations for a school
  static DatabaseReference _busLocationsRef(String schoolId) {
    return _database.ref('bus_locations/$schoolId');
  }

  /// Get reference to a specific bus location
  static DatabaseReference _busLocationRef(String schoolId, String busId) {
    return _database.ref('bus_locations/$schoolId/$busId');
  }

  /// Stream all bus locations for a school
  static Stream<Map<String, BusLocation>> streamBusLocations(String schoolId) {
    return _busLocationsRef(schoolId).onValue.handleError((error) {
      print('Error streaming bus locations: $error');
      return null;
    }).where((event) => event != null).map((event) {
      final data = event!.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <String, BusLocation>{};

      final Map<String, BusLocation> locations = {};
      data.forEach((busId, busData) {
        if (busData is Map) {
          locations[busId] = BusLocation.fromRealtimeDb(
            busId,
            schoolId,
            busData,
          );
        }
      });
      return locations;
    });
  }

  /// Stream a specific bus location
  static Stream<BusLocation?> streamBusLocation(String schoolId, String busId) {
    return _busLocationRef(schoolId, busId).onValue.handleError((error) {
      print('Error streaming bus location: $error');
      return null;
    }).where((event) => event != null).map((event) {
      final data = event!.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      return BusLocation.fromRealtimeDb(busId, schoolId, data);
    });
  }

  /// Get current location of a specific bus (one-time read)
  static Future<BusLocation?> getBusLocation(String schoolId, String busId) async {
    try {
      final snapshot = await _busLocationRef(schoolId, busId).get();
      if (!snapshot.exists) return null;
      
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;
      
      return BusLocation.fromRealtimeDb(busId, schoolId, data);
    } catch (e) {
      print('Error getting bus location: $e');
      return null;
    }
  }

  /// Get all bus locations for a school (one-time read)
  static Future<Map<String, BusLocation>> getAllBusLocations(String schoolId) async {
    try {
      final snapshot = await _busLocationsRef(schoolId).get();
      if (!snapshot.exists) return {};
      
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return {};

      final Map<String, BusLocation> locations = {};
      data.forEach((busId, busData) {
        if (busData is Map) {
          locations[busId] = BusLocation.fromRealtimeDb(
            busId,
            schoolId,
            busData,
          );
        }
      });
      return locations;
    } catch (e) {
      print('Error getting all bus locations: $e');
      return {};
    }
  }

  /// Update bus location (typically called from mobile app)
  static Future<void> updateBusLocation(BusLocation location) async {
    try {
      await _busLocationRef(location.schoolId, location.busId)
          .set(location.toRealtimeDb());
    } catch (e) {
      print('Error updating bus location: $e');
      rethrow;
    }
  }

  /// Update only specific fields of bus location
  static Future<void> updateBusLocationFields(
    String schoolId,
    String busId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _busLocationRef(schoolId, busId).update(updates);
    } catch (e) {
      print('Error updating bus location fields: $e');
      rethrow;
    }
  }

  /// Mark bus as online/offline
  static Future<void> setBusOnlineStatus(
    String schoolId,
    String busId,
    bool isOnline,
  ) async {
    try {
      await _busLocationRef(schoolId, busId).update({
        'isOnline': isOnline,
        'lastUpdated': DateTime.now().toIso8601String(),
        if (!isOnline) 'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error setting bus online status: $e');
      rethrow;
    }
  }

  /// Remove bus location data
  static Future<void> removeBusLocation(String schoolId, String busId) async {
    try {
      await _busLocationRef(schoolId, busId).remove();
    } catch (e) {
      print('Error removing bus location: $e');
      rethrow;
    }
  }

  /// Check if bus is currently online (based on last update time)
  static Future<bool> isBusOnline(String schoolId, String busId) async {
    try {
      final location = await getBusLocation(schoolId, busId);
      if (location == null) return false;
      
      // Consider bus online if last update was within 5 minutes
      final now = DateTime.now();
      final difference = now.difference(location.timestamp);
      return difference.inMinutes <= 5 && location.isOnline;
    } catch (e) {
      print('Error checking bus online status: $e');
      return false;
    }
  }

  /// Get count of online buses for a school
  static Future<int> getOnlineBusCount(String schoolId) async {
    try {
      final locations = await getAllBusLocations(schoolId);
      return locations.values.where((loc) => 
        loc.isOnline && !loc.isStale
      ).length;
    } catch (e) {
      print('Error getting online bus count: $e');
      return 0;
    }
  }

  /// Listen to connection state
  static Stream<bool> connectionStateStream() {
    return _database.ref('.info/connected').onValue.handleError((error) {
      print('Error streaming connection state: $error');
      return null;
    }).where((event) => event != null).map((event) {
      return event!.snapshot.value as bool? ?? false;
    });
  }
}
