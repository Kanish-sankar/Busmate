import 'dart:async';
import 'dart:isolate';
import 'dart:developer' as dev;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:background_locator_2/location_dto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_storage/get_storage.dart';

import 'package:busmate/firebase_options.dart';
import 'package:busmate/meta/model/bus_model.dart';
import 'package:latlong2/latlong.dart';

const String isolateName = 'LocatorIsolate';
const String storageChannel = 'storage_channel';
const String trackingFlagKey = 'driverTrackingEnabled';

// Add these constants at the top with other constants
// ignore: constant_identifier_names
const double MIN_DISTANCE_CHANGE = 10.0; // 10 meters
// ignore: constant_identifier_names
const double MIN_TIME_BETWEEN_UPDATES = 2000; // 2 seconds in milliseconds

// Add these constants at the top with other constants
const int MAX_SKIPPED_STOPS = 2; // Maximum number of stops that can be skipped

void log(String message) {
  dev.log(message);
  if (kDebugMode) {
    print(message);
  }
}

/// Called once when the background isolate is started.
/// Use this to initialize any plugins (Firebase, storage, etc).

@pragma('vm:entry-point')
Future<void> initBackgroundCallback(Map<dynamic, dynamic> params) async {
  try {
    log('🚀 [BackgroundLocator] Initializing background isolate...');

    // Ensure Flutter is initialized in this isolate
    WidgetsFlutterBinding.ensureInitialized();
    log('🔧 [BackgroundLocator] Flutter binding initialized');

    // Setup port for communication between isolates
    final ReceivePort port = ReceivePort();
    if (IsolateNameServer.lookupPortByName(isolateName) != null) {
      IsolateNameServer.removePortNameMapping(isolateName);
    }
    IsolateNameServer.registerPortWithName(port.sendPort, isolateName);
    log('📡 [BackgroundLocator] Port registered: $isolateName');

    // Initialize storage - use await and catch errors
    try {
      await GetStorage.init();
      log('📦 [BackgroundLocator] GetStorage initialized');
    } catch (e) {
      log('⚠️ [BackgroundLocator] GetStorage init error: $e');
    }

    // Extract data from params first
    String? schoolId = params['schoolId']?.toString();
    String? busId = params['busId']?.toString();
    String? busRouteType = params['busRouteType']?.toString(); // <-- add this
    log('🔑 [BackgroundLocator] Params data - schoolId: $schoolId, busId: $busId, busRouteType: $busRouteType');

    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('🔥 [BackgroundLocator] Firebase initialized');
    } catch (e) {
      log('⚠️ [BackgroundLocator] Firebase init error: $e');
    }

    // Store the IDs from params into storage for later use
    if (schoolId != null && busId != null) {
      try {
        final storage = GetStorage();
        storage.write('driverSchoolId', schoolId);
        storage.write('driverBusId', busId);
        if (busRouteType != null) {
          storage.write('busRouteType', busRouteType); // <-- store route type
        }
        log('💾 [BackgroundLocator] IDs saved to storage');

        // Verify storage
        final verifySchoolId = storage.read('driverSchoolId');
        final verifyBusId = storage.read('driverBusId');
        log('🔍 [BackgroundLocator] Verify storage - schoolId: $verifySchoolId, busId: $verifyBusId');
      } catch (e) {
        log('⚠️ [BackgroundLocator] Storage write error: $e');
      }
    }

    log('✅ [BackgroundLocator] Background isolate initialization complete');
  } catch (e, st) {
    log('❌ [BackgroundLocator] Error initializing background isolate: $e');
    log('📜 [BackgroundLocator] Stack trace: $st');
  }
}

// Add this constant at the top with other constants
// ignore: constant_identifier_names
const double STOP_PROXIMITY_THRESHOLD = 200.0; // 200 meters
const double NEAR_STOP_THRESHOLD = 1000.0; // meters (near = within 1km)
const double DELAY_TIME_THRESHOLD = 120.0; // seconds (2 mins)
const double DELAY_SPEED_THRESHOLD = 2.0; // m/s (below this = stuck)
const int ETA_RECALC_INTERVAL = 30; // seconds

// Dual-path location update intervals
const int LIVE_LOCATION_INTERVAL_MS = 3000; // 3 seconds for live tracking (parent app)
const int FULL_LOCATION_INTERVAL_MS = 30000; // 30 seconds for full data (triggers functions)

// Track last write times globally (shared across callback invocations)
final Map<String, int> _lastLiveWriteTime = {};
final Map<String, int> _lastFullWriteTime = {};

@pragma('vm:entry-point')
void backgroundLocationCallback(LocationDto locationDto) async {
  try {
    log('🔄 [BackgroundLocator] Location callback triggered');
    log('📍 [BackgroundLocator] Location received: ${locationDto.latitude}, ${locationDto.longitude}');

    // Get IDs using multiple strategies
    String? schoolId;
    String? busId;
    String? busRouteType;
    bool trackingEnabledFlag = true;

    // Strategy 1: Try GetStorage
    try {
      final storage = GetStorage();
      schoolId = storage.read('driverSchoolId');
      busId = storage.read('driverBusId');
      busRouteType = storage.read('busRouteType'); // <-- read route type
      final dynamic trackingFlagValue = storage.read(trackingFlagKey);
      if (trackingFlagValue != null) {
        trackingEnabledFlag = trackingFlagValue == true;
      }
      log('📦 [BackgroundLocator] From storage - schoolId: $schoolId, busId: $busId, busRouteType: $busRouteType');
    } catch (e) {
      log('⚠️ [BackgroundLocator] GetStorage read error: $e');
    }

    if (!trackingEnabledFlag) {
      log('⏹️ [BackgroundLocator] Tracking disabled flag is false. Skipping update.');
      return;
    }

    // If IDs are missing, we can't update Firestore
    if (schoolId == null || busId == null) {
      log('❌ [BackgroundLocator] Missing IDs, cannot update location');
      return;
    }

    // Initialize Firebase if needed
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      log('🔥 [BackgroundLocator] Firebase initialized');
    }

    // Get current bus data from Realtime Database (unified architecture)
    final database = FirebaseDatabase.instance;
    final busRef = database.ref('bus_locations/$schoolId/$busId');
    final snapshot = await busRef.once();

    if (!snapshot.snapshot.exists || snapshot.snapshot.value == null) {
      log('⚠️ [BackgroundLocator] Bus data not found in Realtime Database');
      log('ℹ️ [BackgroundLocator] Cloud Function will initialize with route schedule');
      // Don't initialize - let the Cloud Function handle it with proper route data
      // This prevents creating generic "Stop1", "Stop2" names
      return;
    }

    final busData = snapshot.snapshot.value as Map<dynamic, dynamic>;
    BusStatusModel status = BusStatusModel.fromMap(
      Map<String, dynamic>.from(busData),
      busId,
    );

    // If busRouteType is not set in status, set it from storage/params
    if (status.busRouteType == null && busRouteType != null) {
      status.busRouteType = busRouteType;
    }

    final now = DateTime.now();
    const Distance distance = Distance();
    final busLocation = LatLng(locationDto.latitude, locationDto.longitude);

    // --- Delay Detection ---
    if (status.lastLatitude != null &&
        status.lastLongitude != null &&
        status.lastMovedTime != null) {
      final movedDist = distance.as(LengthUnit.Meter,
          LatLng(status.lastLatitude!, status.lastLongitude!), busLocation);
      final timeSinceLastMove = now.difference(status.lastMovedTime!).inSeconds;
      if (movedDist < 10 && timeSinceLastMove > DELAY_TIME_THRESHOLD) {}
    }
    // If speed is low for >2 mins, mark as delayed
    if ((locationDto.speed) < DELAY_SPEED_THRESHOLD) {
      if (!status.isDelayed) {
        if (status.lastMovedTime == null) {
          status.lastMovedTime = now;
          status.lastLatitude = locationDto.latitude;
          status.lastLongitude = locationDto.longitude;
        } else {
          final timeStuck = now.difference(status.lastMovedTime!).inSeconds;
          if (timeStuck > DELAY_TIME_THRESHOLD) {
            status.isDelayed = true;
          }
        }
      }
    } else {
      // Reset delay if moving again
      status.isDelayed = false;
      status.lastMovedTime = now;
      status.lastLatitude = locationDto.latitude;
      status.lastLongitude = locationDto.longitude;
    }

    // --- Route Progression & Stop Proximity ---
    String stopStatus = "on route";
    for (var stop in status.remainingStops) {
      final stopLocation = LatLng(stop.latitude, stop.longitude);
      final dist = distance.as(LengthUnit.Meter, busLocation, stopLocation);
      if (dist < 500) {
        stopStatus = "near stop (${stop.name})";
        break;
      } else if (dist < NEAR_STOP_THRESHOLD) {
        stopStatus = "approaching stop (${stop.name})";
        break;
      }
    }
    log('🗺️ [BackgroundLocator] Bus is $stopStatus');

    // --- Handle skipped stops and stop proximity ---
    if (status.remainingStops.isNotEmpty) {
      final routeType = status.busRouteType ?? "pickup";
      final currentStops = List<StopWithETA>.from(status.remainingStops);

      if (routeType == "pickup") {
        // For pickup route: Check if we're near any stop beyond the first one
        for (int i = 1;
            i < currentStops.length && i <= MAX_SKIPPED_STOPS;
            i++) {
          final stop = currentStops[i];
          final stopLocation = LatLng(stop.latitude, stop.longitude);
          final distanceToStop =
              distance.as(LengthUnit.Meter, busLocation, stopLocation);

          if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
            // We're near a later stop, so complete all previous stops
            log('🚏 [BackgroundLocator] Bus reached stop ${i + 1} (${stop.name}) without completing previous stops');
            for (int j = 0; j < i; j++) {
              final skippedStop = currentStops[j];
              log('✅ [BackgroundLocator] Auto-completing skipped stop: ${skippedStop.name}');
              status.remainingStops.removeAt(0); // Remove from front for pickup
            }
            // Now remove the current stop we're at
            status.remainingStops.removeAt(0);
            log('✂️ [BackgroundLocator] Removed reached stop: ${stop.name}');
            break;
          }
        }

        // Normal proximity check for first stop
        if (status.remainingStops.isNotEmpty) {
          final firstStop = status.remainingStops.first;
          final stopLocation = LatLng(firstStop.latitude, firstStop.longitude);
          final distanceToStop =
              distance.as(LengthUnit.Meter, busLocation, stopLocation);
          if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
            log('🚏 [BackgroundLocator] Bus reached first stop: ${firstStop.name}');
            status.remainingStops.removeAt(0);
            log('✂️ [BackgroundLocator] Removed stop: ${firstStop.name} from remaining stops');
          }
        }
      } else {
        // For drop route: Check if we're near any stop before the last one
        for (int i = currentStops.length - 2;
            i >= 0 && i >= currentStops.length - MAX_SKIPPED_STOPS - 1;
            i--) {
          final stop = currentStops[i];
          final stopLocation = LatLng(stop.latitude, stop.longitude);
          final distanceToStop =
              distance.as(LengthUnit.Meter, busLocation, stopLocation);

          if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
            // We're near an earlier stop, so complete all later stops
            log('🚏 [BackgroundLocator] Bus reached stop ${i + 1} (${stop.name}) without completing later stops');
            final stopsToRemove = currentStops.length - i - 1;
            for (int j = 0; j < stopsToRemove; j++) {
              final skippedStop = status.remainingStops.last;
              log('✅ [BackgroundLocator] Auto-completing skipped stop: ${skippedStop.name}');
              status.remainingStops.removeLast(); // Remove from end for drop
            }
            // Now remove the current stop we're at
            status.remainingStops.removeLast();
            log('✂️ [BackgroundLocator] Removed reached stop: ${stop.name}');
            break;
          }
        }

        // Normal proximity check for last stop
        if (status.remainingStops.isNotEmpty) {
          final lastStop = status.remainingStops.last;
          final stopLocation = LatLng(lastStop.latitude, lastStop.longitude);
          final distanceToStop =
              distance.as(LengthUnit.Meter, busLocation, stopLocation);
          if (distanceToStop <= STOP_PROXIMITY_THRESHOLD) {
            log('🚏 [BackgroundLocator] Bus reached last stop: ${lastStop.name}');
            status.remainingStops.removeLast();
            log('✂️ [BackgroundLocator] Removed stop: ${lastStop.name} from remaining stops');
          }
        }
      }

      log('📊 [BackgroundLocator] Remaining stops count: ${status.remainingStops.length}');
    }

    // --- Update location and speed ---
    status.latitude = locationDto.latitude;
    status.longitude = locationDto.longitude;
    status.currentSpeed = locationDto.speed;

    // Add speed sample for average calculation
    status.addSpeedSample(locationDto.speed);

    // --- Dual-Path Location Update System ---
    // Path 1: Live location (3 seconds) - for parent app smooth tracking
    // Path 2: Full data (30 seconds) - triggers Cloud Functions for notifications/ETAs
    
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final busKey = '$schoolId/$busId';
    
    // Initialize timestamps if not present
    _lastLiveWriteTime[busKey] ??= 0;
    _lastFullWriteTime[busKey] ??= 0;
    
    final timeSinceLastLive = nowMs - _lastLiveWriteTime[busKey]!;
    final timeSinceLastFull = nowMs - _lastFullWriteTime[busKey]!;
    
    try {
      // Write to live location path every 3 seconds (minimal data, no function triggers)
      if (timeSinceLastLive >= LIVE_LOCATION_INTERVAL_MS) {
        await database
            .ref('live_bus_locations/$schoolId/$busId')
            .update({
              'latitude': locationDto.latitude,
              'longitude': locationDto.longitude,
              'heading': locationDto.heading,
              'speed': locationDto.speed,
              'timestamp': ServerValue.timestamp,
            });
        _lastLiveWriteTime[busKey] = nowMs;
        log('🔵 [BackgroundLocator] Live location updated (3s interval) - no functions triggered');
      }
      
      // Write to full location path every 30 seconds (complete data, triggers functions)
      if (timeSinceLastFull >= FULL_LOCATION_INTERVAL_MS) {
        await database
            .ref('bus_locations/$schoolId/$busId')
            .update({
              'latitude': locationDto.latitude,
              'longitude': locationDto.longitude,
              'speed': locationDto.speed,
              'accuracy': locationDto.accuracy,
              'altitude': locationDto.altitude,
              'heading': locationDto.heading,
              'timestamp': ServerValue.timestamp,
              'source': 'phone',
              // Note: isActive and isWithinTripWindow are NOT updated here
              // They are controlled by: Start/Stop Trip buttons (driver) or handleTripTransitions (Cloud Function scheduler)
              'isDelayed': status.isDelayed,
              'remainingStops': status.remainingStops.map((s) => s.toMap()).toList(),
              'stopsPassedCount': status.stopsPassedCount,
              'totalStops': status.totalStops,
              'lastRecalculationAt': status.lastRecalculationAt ?? 0,
              'lastETACalculation': status.lastETACalculation?.millisecondsSinceEpoch ?? 0,
            });
        _lastFullWriteTime[busKey] = nowMs;
        log('🟢 [BackgroundLocator] Full data updated (30s interval) - triggers Cloud Functions');
      }
      
      log('📍 [BackgroundLocator] Dual-path GPS update complete');
      log('✅ [BackgroundLocator] Cost optimization: 90% reduction in function invocations');
    } catch (e) {
      log('⚠️ [BackgroundLocator] Error updating Realtime Database: $e');
    }
  } catch (e, st) {
    log('❌ [BackgroundLocator] Error in location callback: $e');
    log('📜 [BackgroundLocator] Stack trace: $st');
  }
}

/// Called when the background locator is stopped/disposed.
@pragma('vm:entry-point')
void disposeBackgroundCallback() {
  try {
    log('🛑 [BackgroundLocator] Dispose callback triggered');
    IsolateNameServer.removePortNameMapping(isolateName);
    log('🧹 [BackgroundLocator] Port mapping removed');
    log('👋 [BackgroundLocator] Background service disposed');
  } catch (e) {
    log('❌ [BackgroundLocator] Error in dispose callback: $e');
  }
}
