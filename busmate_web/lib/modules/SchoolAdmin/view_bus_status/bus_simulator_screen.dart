import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:busmate_web/utils/bus_simulator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:busmate_web/modules/SchoolAdmin/bus_management/bus_model.dart';

class BusSimulatorScreen extends StatefulWidget {
  final String schoolId;

  const BusSimulatorScreen({super.key, required this.schoolId});

  @override
  State<BusSimulatorScreen> createState() => _BusSimulatorScreenState();
}

class _BusSimulatorScreenState extends State<BusSimulatorScreen> {
  final BusSimulator simulator = BusSimulator();
  final List<SimulationStatus> runningSimulations = [];
  bool isGeneratingRoute = false;
  List<Bus> availableBuses = [];
  bool isLoadingBuses = true;
  Map<String, Map<String, bool>> busRouteAvailability = {}; // busId -> {pickup: bool, drop: bool}

  @override
  void initState() {
   super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() => isLoadingBuses = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('buses')
          .get();

      availableBuses = snapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();
      
      // Load route availability for each bus
      for (var bus in availableBuses) {
        final schedules = await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('route_schedules')
            .where('busId', isEqualTo: bus.id)
            .where('isActive', isEqualTo: true)
            .get();
        
        busRouteAvailability[bus.id] = {
          'pickup': schedules.docs.any((doc) => doc.data()['direction'] == 'pickup'),
          'drop': schedules.docs.any((doc) => doc.data()['direction'] == 'drop'),
        };
      }
      
      setState(() => isLoadingBuses = false);

      print('📦 Loaded ${availableBuses.length} buses from Firestore');
    } catch (e) {
      print('❌ Error loading buses: $e');
      setState(() => isLoadingBuses = false);
    }
  }

  /// Create initial bus data in Realtime Database for Firebase Function to use
  Future<void> _createInitialBusData({
    required String busId,
    required List<LatLng> route,
    required String routeId,
    required String direction,
    required List<Map<String, dynamic>> stopNames, // Pass actual stop data with names
    required String scheduleStartTime, // Schedule's start time for consistent tripId
    required String scheduleEndTime, // Schedule's end time for isWithinTripWindow calculation
  }) async {
    try {
      print('📝 Creating bus data in Realtime Database for $busId');
      
      // Find the bus object from availableBuses
      final bus = availableBuses.firstWhere((b) => b.id == busId, 
        orElse: () => throw Exception('Bus not found'));
      
      // Convert route to stop format with ACTUAL stop names (without ETAs - let Firebase Function calculate them)
      final stops = route.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        
        // Use actual stop name from route schedule, not generic "Stop 1", "Stop 2"
        final stopName = (index < stopNames.length) 
            ? (stopNames[index]['name'] as String?) ?? 'Stop ${index + 1}'
            : 'Stop ${index + 1}';
        
        return {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'name': stopName, // Use real stop name for matching with student stops
          'estimatedMinutesOfArrival': null, // Will be calculated by Firebase Function
          'distanceMeters': null,
          'eta': null,
        };
      }).toList();

      // Generate tripId using SCHEDULE START TIME (not current time)
      // CRITICAL: Must match Cloud Function's tripId format for student queries
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final tripId = '${routeId}_${dateKey}_${scheduleStartTime.replaceAll(':', '')}';
      
      print('🆔 Generated tripId using schedule time: $tripId (schedule: $scheduleStartTime)');
      
      // Calculate if current time is within schedule window
      final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final isWithinWindow = _isTimeWithinSchedule(currentTimeStr, scheduleStartTime, scheduleEndTime);
      print('⏰ Time check: Current=$currentTimeStr, Start=$scheduleStartTime, End=$scheduleEndTime, Within=$isWithinWindow');
      
      // Create/update bus data in Realtime Database
      await FirebaseDatabase.instance
          .ref('bus_locations/${widget.schoolId}/$busId')
          .set({
        'latitude': route.first.latitude,
        'longitude': route.first.longitude,
        'speed': 0,
        'source': 'web_simulator',
        'isActive': true, // Must be true for Firebase Function to process
        'isWithinTripWindow': isWithinWindow, // Calculate based on schedule times
        'activeRouteId': routeId, // Set active route for Firebase Function
        'currentTripId': tripId, // CRITICAL: Match with students for notifications
        'tripDirection': direction, // 'pickup' or 'drop'
        'routeName': '${bus.busVehicleNo} - ${direction == "pickup" ? "Morning Pickup" : "Evening Drop"}',
        'scheduleStartTime': scheduleStartTime, // Use schedule's start time, not current time
        'scheduleEndTime': scheduleEndTime, // Store end time for reference
        'tripStartedAt': now.millisecondsSinceEpoch,
        'remainingStops': stops,
        'totalStops': stops.length,
        'stopsPassedCount': 0,
        'lastRecalculationAt': 0,
        'lastETACalculation': 0, // Set to 0 to force initial calculation
        'startTime': now.millisecondsSinceEpoch,
      });
      
      print('✅ Bus data created in Realtime Database for $busId with ${stops.length} stops ($direction route)');
      
      // CRITICAL: Reset students when manually starting simulation
      // This ensures student.currentTripId matches bus.currentTripId for notification query
      print('👥 Resetting students to match trip $tripId...');
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('students')
          .where('assignedBusId', isEqualTo: busId)
          .get();
      
      if (studentsSnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in studentsSnapshot.docs) {
          batch.update(doc.reference, {
            'notified': false,
            'currentTripId': tripId, // MUST MATCH bus.currentTripId for query to work!
            'tripStartedAt': DateTime.now().millisecondsSinceEpoch,
            'lastNotifiedRoute': routeId,
            'lastNotifiedAt': null,
          });
        }
        await batch.commit();
        print('✅ Reset ${studentsSnapshot.docs.length} students with matching tripId');
      } else {
        print('⚠️ No students assigned to bus $busId');
      }
      print('⏳ Initial ETA calculation will happen on first GPS update...');
    } catch (e) {
      print('❌ Error creating bus data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.settings_remote, size: 48, color: Colors.purple[700]),
                      const SizedBox(height: 12),
                      Text(
                        'Bus Location Simulator',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simulate bus movements for testing real-time tracking',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'School ID: ${widget.schoolId}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Available Buses Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Buses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (runningSimulations.isNotEmpty)
                      TextButton.icon(
                        onPressed: _stopAllSimulations,
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        label: const Text('Stop All', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Buses List
                Expanded(
                  child: isLoadingBuses
                      ? const Center(child: CircularProgressIndicator())
                      : availableBuses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No buses found',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add buses in Bus Management first',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: availableBuses.length,
                              itemBuilder: (context, index) {
                                final bus = availableBuses[index];
                                final isRunning = runningSimulations.any((sim) => sim.busId == bus.busVehicleNo);
                                return _buildBusCard(bus, isRunning);
                              },
                            ),
                ),
                
                const SizedBox(height: 16),
                
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'After starting simulation, go to "View Bus Status" to see buses moving on the map in real-time!',
                          style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusCard(Bus bus, bool isRunning) {
    final hasPickup = busRouteAvailability[bus.id]?['pickup'] ?? false;
    final hasDrop = busRouteAvailability[bus.id]?['drop'] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Bus Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRunning ? Colors.green[100] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: isRunning ? Colors.green[700] : Colors.blue[700],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Bus Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.busNo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vehicle: ${bus.busVehicleNo}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (hasPickup || hasDrop) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (hasPickup) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Pickup',
                                  style: TextStyle(fontSize: 11, color: Colors.green[900]),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (hasDrop) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Drop',
                                  style: TextStyle(fontSize: 11, color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action Button
                if (isRunning)
                  ElevatedButton.icon(
                    onPressed: () => _stopBusSimulation(bus.busVehicleNo),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            
            // Route Selection Buttons (if not running)
            if (!isRunning && (hasPickup || hasDrop)) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasPickup)
                    ElevatedButton.icon(
                      onPressed: () => _startBusSimulation(bus, routeType: 'pickup'),
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      label: const Text('Start Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (hasPickup && hasDrop) const SizedBox(width: 8),
                  if (hasDrop)
                    ElevatedButton.icon(
                      onPressed: () => _startBusSimulation(bus, routeType: 'drop'),
                      icon: const Icon(Icons.arrow_downward, size: 16),
                      label: const Text('Start Drop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }



  Future<void> _startBusSimulation(Bus bus, {required String routeType}) async {
    if (isGeneratingRoute) return;
    
    setState(() => isGeneratingRoute = true);
    
    try {
      // Query route schedule by busId and direction
      final routeQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('route_schedules')
          .where('busId', isEqualTo: bus.id)
          .where('direction', isEqualTo: routeType)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (routeQuery.docs.isEmpty) {
        Get.snackbar(
          'Error',
          'No active $routeType route schedule found for this bus',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
        setState(() => isGeneratingRoute = false);
        return;
      }
      
      final routeDoc = routeQuery.docs.first;
      final routeId = routeDoc.id;
      final routeData = routeDoc.data();
      final stoppings = routeData['stops'] as List<dynamic>? ?? routeData['stoppings'] as List<dynamic>? ?? [];
      final scheduleStartTime = routeData['startTime'] as String? ?? ''; // Get schedule's start time
      final routeName = routeData['routeName'] as String? ?? 'Unknown Route';
      
      // Use actual route stops if available, otherwise generate test route
      List<LatLng> route;
      List<LatLng>? polyline;
      
      if (stoppings.isNotEmpty) {
        // Debug: Print ALL stop data to see structure
        print('🔍 Route has ${stoppings.length} stops');
        print('🔍 First stop full data: ${stoppings.first}');
        
        // Use actual route from schedule
        route = stoppings.map((stop) {
          // Stops are stored with nested location object: {name: "X", location: {latitude: Y, longitude: Z}}
          final location = stop['location'];
          
          double lat, lng;
          
          if (location != null && location is Map) {
            // New format: nested location object
            lat = ((location['latitude'] ?? 11.0168) as num).toDouble();
            lng = ((location['longitude'] ?? 76.9558) as num).toDouble();
          } else {
            // Old format: direct latitude/longitude fields
            lat = ((stop['latitude'] ?? stop['lat'] ?? 11.0168) as num).toDouble();
            lng = ((stop['longitude'] ?? stop['lng'] ?? 76.9558) as num).toDouble();
          }
          
          print('  📌 Stop: ${stop['name'] ?? 'Unknown'} at ($lat, $lng)');
          
          return LatLng(lat, lng);
        }).toList();
        
        print('📍 Using ${route.length} stops from $routeType route');
        print('📍 Route points: ${route.map((p) => "(${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)})").join(", ")}');
      } else {
        print('⚠️ Route has NO stops, generating test route');
        // Generate test route if no stops available
        route = BusSimulator.generateTestRoute(
          center: const LatLng(11.0168, 76.9558),
          stopCount: 12,
          radiusKm: 4.0,
        );
        print('📍 Generated ${route.length} test stops');
      }

      final sim = SimulationStatus(
        busId: bus.id, // Use bus document ID
        busNo: bus.busNo,
        routeName: routeName,
        stopCount: route.length,
      );

      setState(() {
        runningSimulations.add(sim);
        isGeneratingRoute = false;
      });

      Get.snackbar(
        'Simulation Started',
        'Bus ${bus.busNo} moving between ${route.length} stops ($routeType route)',
        backgroundColor: Colors.green[100],
        colorText: Colors.green[900],
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );

      // Create initial bus data in Realtime Database for Firebase Function
      final scheduleEndTime = routeData['endTime'] as String? ?? '23:59'; // Get schedule's end time
      await _createInitialBusData(
        busId: bus.id, // Use bus document ID
        route: route,
        routeId: routeId,
        direction: routeType,
        stopNames: stoppings.cast<Map<String, dynamic>>(), // Pass full stop data with names
        scheduleStartTime: scheduleStartTime, // Pass schedule start time for tripId generation
        scheduleEndTime: scheduleEndTime, // Pass schedule end time for isWithinTripWindow calculation
      );

      // Extract stop names for display in simulator
      final stopNamesList = stoppings.map((stop) => stop['name'] as String? ?? 'Unknown Stop').toList();

      // Start simulation (runs in background)
      simulator.simulateBusMovement(
        schoolId: widget.schoolId,
        busId: bus.id, // Use bus document ID
        driverId: bus.driverId ?? 'sim_driver',
        driverName: bus.driverName ?? 'Simulator Driver',
        routeId: routeId,
        routeName: routeName,
        routePoints: route,
        routePolyline: polyline, // Pass OSRM polyline for realistic road-following
        stopNames: stopNamesList, // Pass actual stop names
        totalStudents: bus.assignedStudents.length,
      ).then((_) {
        // Simulation completed
        if (mounted) {
          setState(() {
            runningSimulations.removeWhere((s) => s.busId == bus.id);
          });
        }
      });
    } catch (e) {
      setState(() => isGeneratingRoute = false);
      Get.snackbar(
        'Error',
        'Failed to start simulation: $e',
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  void _stopBusSimulation(String busId) {
    setState(() {
      runningSimulations.removeWhere((sim) => sim.busId == busId);
    });
    
    // Set bus offline in database
    BusSimulator.setBusOffline(widget.schoolId, busId);
    
    Get.snackbar(
      'Simulation Stopped',
      'Bus $busId simulation stopped',
      backgroundColor: Colors.orange[100],
      colorText: Colors.orange[900],
      icon: const Icon(Icons.info, color: Colors.orange),
    );
  }

  void _stopAllSimulations() {
    final count = runningSimulations.length;
    setState(() {
      runningSimulations.clear();
    });
    
    Get.snackbar(
      'All Simulations Stopped',
      '$count simulation(s) stopped',
      backgroundColor: Colors.red[100],
      colorText: Colors.red[900],
      icon: const Icon(Icons.stop_circle, color: Colors.red),
    );
  }

  /// Check if current time is within schedule window (startTime <= current <= endTime)
  bool _isTimeWithinSchedule(String currentTime, String startTime, String endTime) {
    try {
      // Parse times as HH:mm format
      final current = _parseTimeToMinutes(currentTime);
      final start = _parseTimeToMinutes(startTime);
      final end = _parseTimeToMinutes(endTime);
      
      // Handle overnight schedules (e.g., 23:00 to 01:00)
      if (end < start) {
        // Overnight: current >= start OR current <= end
        return current >= start || current <= end;
      } else {
        // Same day: start <= current <= end
        return current >= start && current <= end;
      }
    } catch (e) {
      print('⚠️ Error parsing schedule times: $e');
      return false; // Default to false if parsing fails
    }
  }

  /// Convert HH:mm time string to minutes since midnight for easy comparison
  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }
}

class SimulationStatus {
  final String busId; // Vehicle number (e.g., TN37A1000)
  final String busNo;
  final String routeName;
  final int stopCount;

  SimulationStatus({
    required this.busId,
    required this.busNo,
    required this.routeName,
    required this.stopCount,
  });
}
