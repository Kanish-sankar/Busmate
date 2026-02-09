import 'dart:async';
import 'package:busmate_web/models/bus_location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Mock service for bus locations using Firestore (works on web)
/// This is a temporary solution for web testing until we integrate real GPS devices
class BusLocationServiceWeb {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to bus locations collection for a school
  static CollectionReference _busLocationsRef(String schoolId) {
    return _firestore
        .collection('bus_locations_web')
        .doc(schoolId)
        .collection('buses');
  }

  /// Stream all bus locations for a school
  static Stream<Map<String, BusLocation>> streamBusLocations(String schoolId) {
    // Streaming bus locations from Firestore
    
    return _busLocationsRef(schoolId).snapshots().map((snapshot) {
      print('📦 Received ${snapshot.docs.length} bus location documents');
      
      final Map<String, BusLocation> locations = {};
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          locations[doc.id] = BusLocation.fromJson(data);
          print('  ✓ Loaded location for bus: ${doc.id}');
        } catch (e) {
          print('  ✗ Error parsing bus ${doc.id}: $e');
        }
      }
      
      return locations;
    });
  }

  /// Stream a specific bus location
  static Stream<BusLocation?> streamBusLocation(String schoolId, String busId) {
    return _busLocationsRef(schoolId).doc(busId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      return BusLocation.fromJson(data);
    });
  }

  /// Get current location of a specific bus (one-time read)
  static Future<BusLocation?> getBusLocation(String schoolId, String busId) async {
    try {
      final doc = await _busLocationsRef(schoolId).doc(busId).get();
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return BusLocation.fromJson(data);
    } catch (e) {
      print('Error getting bus location: $e');
      return null;
    }
  }

  /// Get all bus locations (one-time read)
  static Future<Map<String, BusLocation>> getAllBusLocations(String schoolId) async {
    try {
      final snapshot = await _busLocationsRef(schoolId).get();
      
      final Map<String, BusLocation> locations = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        locations[doc.id] = BusLocation.fromJson(data);
      }
      
      return locations;
    } catch (e) {
      print('Error getting all bus locations: $e');
      return {};
    }
  }

  /// Update bus location
  static Future<void> updateBusLocation(BusLocation location) async {
    try {
      await _busLocationsRef(location.schoolId)
          .doc(location.busId)
          .set(location.toJson(), SetOptions(merge: true));
      
      print('✓ Updated location for bus ${location.busId}');
    } catch (e) {
      print('✗ Error updating bus location: $e');
      rethrow;
    }
  }

  /// Set bus online/offline status
  static Future<void> setBusOnlineStatus(
    String schoolId,
    String busId,
    bool isOnline,
  ) async {
    try {
      await _busLocationsRef(schoolId).doc(busId).update({
        'isOnline': isOnline,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error setting bus online status: $e');
      rethrow;
    }
  }

  /// Check if bus is online (location updated within last 5 minutes)
  static Future<bool> isBusOnline(String schoolId, String busId) async {
    try {
      final location = await getBusLocation(schoolId, busId);
      if (location == null) return false;
      
      return !location.isStale;
    } catch (e) {
      print('Error checking bus online status: $e');
      return false;
    }
  }

  /// Get count of online buses
  static Future<int> getOnlineBusCount(String schoolId) async {
    try {
      final locations = await getAllBusLocations(schoolId);
      return locations.values.where((loc) => loc.isOnline && !loc.isStale).length;
    } catch (e) {
      print('Error getting online bus count: $e');
      return 0;
    }
  }

  /// Delete bus location
  static Future<void> deleteBusLocation(String schoolId, String busId) async {
    try {
      await _busLocationsRef(schoolId).doc(busId).delete();
      print('✓ Deleted location for bus $busId');
    } catch (e) {
      print('✗ Error deleting bus location: $e');
      rethrow;
    }
  }
}
