import 'dart:async';
import 'package:busmate_web/models/bus_location.dart';
import 'package:busmate_web/services/bus_location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ViewBusStatusController extends GetxController {
  final String schoolId;
  
  // Observable data
  var isLoading = true.obs;
  var buses = <BusWithLocation>[].obs;
  var selectedBus = Rx<BusWithLocation?>(null);
  var filterStatus = 'all'.obs; // 'all', 'online', 'offline', 'allbuses'
  var showAllBusesOnMap = false.obs; // Show all buses on map instead of selected one
  
  // Streams
  StreamSubscription? _busLocationsSubscription;
  
  ViewBusStatusController({required this.schoolId});
  
  @override
  void onInit() {
    super.onInit();
    _loadBusesAndStartTracking();
  }
  
  @override
  void onClose() {
    _busLocationsSubscription?.cancel();
    super.onClose();
  }
  
  /// Load all buses and start real-time tracking
  Future<void> _loadBusesAndStartTracking() async {
    try {
      isLoading.value = true;
      
      print('🔍 Loading buses for school: $schoolId');
      
      // Load bus list from Firestore
      final busesSnapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(schoolId)
          .collection('buses')
          .get();
      
      print('📊 Found ${busesSnapshot.docs.length} buses in Firestore');
      
      if (busesSnapshot.docs.isEmpty) {
        print('⚠️ No buses found in Firestore at: schooldetails/$schoolId/buses');
        isLoading.value = false;
        buses.value = []; // Set empty list
        return;
      }
      
      // Log bus details
      for (final doc in busesSnapshot.docs) {
        final data = doc.data();
        print('  Bus ${doc.id}: ${data['busNo']} - ${data['driverName'] ?? 'No driver'}');
      }
      
      // Initialize buses list immediately with offline status
      _updateBusesWithLocations(busesSnapshot.docs, {});
      
      // Start listening to real-time location updates from Realtime Database
      _busLocationsSubscription = BusLocationService
          .streamBusLocations(schoolId)
          .listen((locations) {
        print('📡 Received ${locations.length} location updates from Realtime Database');
        _updateBusesWithLocations(busesSnapshot.docs, locations);
      });
      
      isLoading.value = false;
    } catch (e) {
      print('❌ Error loading buses: $e');
      isLoading.value = false;
      Get.snackbar('Error', 'Unable to load buses. Please refresh the page.');
    }
  }
  
  /// Update buses list with real-time location data
  void _updateBusesWithLocations(
    List<QueryDocumentSnapshot> busDocs,
    Map<String, BusLocation> locations,
  ) {
    final updatedBuses = <BusWithLocation>[];
    
    print('📦 Received ${locations.length} bus location documents');
    
    for (final doc in busDocs) {
      final busData = doc.data() as Map<String, dynamic>;
      final busId = doc.id;
      final busVehicleNo = busData['busVehicleNo'] as String?;
      
      // Match by vehicle number (used as key in Realtime Database)
      // Try both document ID and vehicle number for backward compatibility
      final location = (busVehicleNo != null ? locations[busVehicleNo] : null) ?? locations[busId];
      
      if (location != null) {
        print('  ✓ Loaded location for bus: ${busData['busNo']} (Vehicle: $busVehicleNo)');
      }
      
      updatedBuses.add(BusWithLocation(
        id: busId,
        busNo: busData['busNo'] ?? 'Unknown',
        driverName: busData['driverName'] ?? 'No driver',
        routeName: busData['routeName'] ?? 'No route assigned',
        capacity: busData['capacity'] ?? 0,
        location: location,
      ));
    }
    
    // Sort: Online buses first
    updatedBuses.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return a.busNo.compareTo(b.busNo);
    });
    
    buses.value = updatedBuses;
  }
  
  /// Get filtered buses based on status filter
  List<BusWithLocation> get filteredBuses {
    if (filterStatus.value == 'online') {
      return buses.where((b) => b.isOnline).toList();
    } else if (filterStatus.value == 'offline') {
      return buses.where((b) => !b.isOnline).toList();
    } else if (filterStatus.value == 'allbuses') {
      // Return all buses (for map view showing all buses)
      return buses;
    }
    return buses;
  }
  
  /// Get online bus count
  int get onlineBusCount => buses.where((b) => b.isOnline).length;
  
  /// Get offline bus count
  int get offlineBusCount => buses.where((b) => !b.isOnline).length;
  
  /// Select a bus to view details
  void selectBus(BusWithLocation? bus) {
    selectedBus.value = bus;
  }
  
  /// Set filter status
  void setFilter(String filter) {
    filterStatus.value = filter;
  }
  
  /// Force refresh bus locations
  @override
  Future<void> refresh() async {
    isLoading.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadBusesAndStartTracking();
  }
  
  /// Toggle showing all buses on map
  void toggleAllBusesView() {
    showAllBusesOnMap.value = !showAllBusesOnMap.value;
    if (showAllBusesOnMap.value) {
      selectedBus.value = null; // Deselect individual bus when showing all
    }
  }
  
  /// Show all buses on map
  void showAllBuses() {
    showAllBusesOnMap.value = true;
    selectedBus.value = null;
  }
}

/// Model combining bus info with real-time location
class BusWithLocation {
  final String id;
  final String busNo;
  final String driverName;
  final String routeName;
  final int capacity;
  final BusLocation? location;
  
  BusWithLocation({
    required this.id,
    required this.busNo,
    required this.driverName,
    required this.routeName,
    required this.capacity,
    this.location,
  });
  
  // Bus is only online if location exists, isOnline flag is true, AND location is not stale (< 5 minutes old)
  bool get isOnline {
    if (location == null) return false;
    if (!location!.isOnline) return false;
    
    // Check if location is stale (older than 5 minutes)
    final now = DateTime.now();
    final difference = now.difference(location!.timestamp);
    if (difference.inMinutes >= 5) return false;
    
    return true;
  }
  
  bool get isMoving => location != null && location!.status == BusStatus.moving;
  
  bool get isStopped => location != null && location!.status == BusStatus.stopped;
  
  bool get isIdle => location != null && location!.status == BusStatus.idle;
  
  String get statusText {
    if (location == null || !isOnline) return 'Offline';
    
    switch (location!.status) {
      case BusStatus.moving:
        return 'Moving';
      case BusStatus.stopped:
        return 'Stopped';
      case BusStatus.idle:
        return 'Idle';
    }
  }
  
  Color get statusColor {
    if (!isOnline) return Colors.red;
    
    switch (location?.status) {
      case BusStatus.moving:
        return Colors.green;
      case BusStatus.stopped:
        return Colors.orange;
      case BusStatus.idle:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  IconData get statusIcon {
    if (!isOnline) return Icons.power_off;
    
    switch (location?.status) {
      case BusStatus.moving:
        return Icons.directions_bus;
      case BusStatus.stopped:
        return Icons.pause_circle;
      case BusStatus.idle:
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }
}
