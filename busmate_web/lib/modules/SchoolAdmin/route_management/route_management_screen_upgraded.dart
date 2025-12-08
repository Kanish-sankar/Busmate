import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:busmate_web/modules/SchoolAdmin/route_management/route_controller.dart';
import 'package:busmate_web/services/osrm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class RouteManagementScreenUpgraded extends StatefulWidget {
  final String routeId;
  final String routeName;
  final String schoolId;

  const RouteManagementScreenUpgraded({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.schoolId,
  });

  @override
  State<RouteManagementScreenUpgraded> createState() => _RouteManagementScreenUpgradedState();
}

class _RouteManagementScreenUpgradedState extends State<RouteManagementScreenUpgraded> {
  late final RouteController routeController;
  final MapController _mapController = MapController();
  final bool _showSatellite = false;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PlaceSuggestion> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  PlaceSuggestion? _selectedSearchResult; // Track selected place from search
  
  // Stop repositioning functionality
  int? _repositioningStopIndex; // Track which stop is being repositioned
  bool _isWaypointMode = false; // Track if in waypoint adding mode

  @override
  void initState() {
    super.initState();
    routeController = Get.put(RouteController(), tag: widget.routeId);
    routeController.init(widget.routeId, schoolId: widget.schoolId);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Left Panel - Map + Controls
          Expanded(
            flex: 7,
            child: Column(
              children: [
                // Stats Bar
                _buildStatsBar(),
                
                // Map
                Expanded(
                  child: _buildMap(),
                ),
              ],
            ),
          ),
          
          // Right Panel - Stops List
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: _buildStopsPanel(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.route, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.routeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Route Management',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Direction Toggle (UP/DOWN)
        _buildDirectionToggle(),
        
        const SizedBox(width: 8),
        const VerticalDivider(),
        const SizedBox(width: 8),
        
        // Bus Assignment Button
        _buildBusAssignmentButton(),
        
        const SizedBox(width: 8),
        const VerticalDivider(),
        const SizedBox(width: 8),
        
        // Waypoint Mode Toggle Button
        _buildWaypointModeButton(),
        
        const SizedBox(width: 8),
        const VerticalDivider(),
        const SizedBox(width: 8),
        
        // Save Button
        Obx(() {
          return ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Route'),
            onPressed: routeController.stops.isEmpty ? null : _saveRoute,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          );
        }),
        
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 60,
        child: Obx(() {
          final stopCount = routeController.stops.length;
          final distance = routeController.calculateDistance() / 1000;
          final estimatedTime = (distance / 30 * 60).toInt();

          final isUp = routeController.currentDirection.value == 'up';
          final directionText = isUp ? 'UP (Home → School)' : 'DOWN (School → Home)';
          final directionColor = isUp ? Colors.blue : Colors.orange;
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Direction Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: directionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 20,
                      color: directionColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      directionText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: directionColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildStatChip(
                icon: Icons.location_on,
                label: 'Stops',
                value: stopCount.toString(),
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.straighten,
                label: 'Distance',
                value: '${distance.toStringAsFixed(1)} km',
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.access_time,
                label: 'Est. Time',
                value: '$estimatedTime min',
                color: Colors.orange,
              ),
              const Spacer(),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.route, color: Colors.blue),
                  onPressed: routeController.stops.isEmpty ? null : () {
                    routeController.snapAllStopsToRoad();
                  },
                  tooltip: 'Snap all stops to nearest road',
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: routeController.stops.isEmpty ? null : _clearAllStops,
                  tooltip: 'Clear all stops',
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
  
  Widget _buildDirectionToggle() {
    return Obx(() {
      final isUp = routeController.currentDirection.value == 'up';
      final frozenStops = routeController.getFrozenStops();
      final hasFrozenRoute = frozenStops.isNotEmpty;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UP Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  routeController.switchDirection('up');
                  Get.snackbar(
                    '🔼 UP Route Active',
                    'Now editing Home → School route',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUp ? Colors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: isUp ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'UP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isUp ? Colors.white : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 4),
            
            // DOWN Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  routeController.switchDirection('down');
                  Get.snackbar(
                    '🔽 DOWN Route Active',
                    hasFrozenRoute 
                        ? 'Now editing School → Home route (UP route shown as reference)'
                        : 'Now editing School → Home route',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: !isUp ? Colors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: !isUp ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DOWN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: !isUp ? Colors.white : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildWaypointModeButton() {
    return ElevatedButton.icon(
      icon: Icon(
        _isWaypointMode ? Icons.location_on : Icons.add_location_alt,
        size: 18,
        color: _isWaypointMode ? Colors.white : null,
      ),
      label: Text(_isWaypointMode ? 'Waypoint Mode ON' : 'Add Waypoints'),
      onPressed: () {
        setState(() {
          _isWaypointMode = !_isWaypointMode;
          if (_isWaypointMode) {
            // Cancel repositioning if active
            _repositioningStopIndex = null;
            Get.snackbar(
              '📍 Waypoint Mode Active',
              'Click on the map to add waypoints between stops',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.purple,
              colorText: Colors.white,
            );
          }
        });
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _isWaypointMode ? Colors.purple : null,
        foregroundColor: _isWaypointMode ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildBusAssignmentButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('routes')
          .doc(widget.routeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        
        final routeData = snapshot.data!.data() as Map<String, dynamic>?;
        final assignedBusId = routeData?['assignedBusId'] as String?;
        
        if (assignedBusId != null) {
          // Show assigned bus
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('schooldetails')
                .doc(widget.schoolId)
                .collection('buses')
                .doc(assignedBusId)
                .get(),
            builder: (context, busSnapshot) {
              if (busSnapshot.hasData && busSnapshot.data!.exists) {
                final busData = busSnapshot.data!.data() as Map<String, dynamic>;
                return PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Bus ${busData['busNo']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: Colors.green),
                      ],
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'change') {
                      _showBusAssignmentDialog();
                    } else if (value == 'remove') {
                      _removeBusAssignment();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'change',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 18),
                          SizedBox(width: 8),
                          Text('Change Bus'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.remove_circle, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Bus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          );
        } else {
          // No bus assigned
          return TextButton.icon(
            icon: const Icon(Icons.add_circle, size: 16),
            label: const Text('Assign Bus'),
            onPressed: _showBusAssignmentDialog,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          );
        }
      },
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    const LatLng defaultCenter = LatLng(11.0168, 76.9558); // Coimbatore

    return Stack(
      children: [
        Obx(() {
          LatLng center = routeController.stops.isNotEmpty
              ? routeController.stops.first.location
              : defaultCenter;

      List<Widget> mapChildren = [
        // Base map tiles
        TileLayer(
          urlTemplate: _showSatellite
              ? "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}"
              : "https://tile.openstreetmap.org/{z}/{x}/{y}.png", // Don't use subdomains
          tileProvider: CancellableNetworkTileProvider(),
        ),
      ];

      // Add 50m pickup/drop zones around each stop
      // These zones work for BOTH up and down routes!
      if (routeController.stops.isNotEmpty) {
        mapChildren.add(
          CircleLayer(
            circles: routeController.stops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              final isFirst = index == 0;
              final isLast = index == routeController.stops.length - 1;
              
              return CircleMarker(
                point: stop.location,
                radius: 50, // 50 meters pickup/drop zone
                useRadiusInMeter: true,
                color: isFirst 
                    ? Colors.green.withOpacity(0.15)
                    : isLast
                        ? Colors.red.withOpacity(0.15)
                        : Colors.blue.withOpacity(0.15),
                borderColor: isFirst
                    ? Colors.green.withOpacity(0.5)
                    : isLast
                        ? Colors.red.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.5),
                borderStrokeWidth: 2,
              );
            }).toList(),
          ),
        );
      }

      // Add frozen route polyline (opposite direction) as reference - darker and more visible
      final frozenPolyline = routeController.getFrozenPolyline();
      final frozenStops = routeController.getFrozenStops();
      if (frozenPolyline.isNotEmpty) {
        mapChildren.add(
          PolylineLayer(
            polylines: [
              Polyline(
                points: frozenPolyline,
                strokeWidth: 4.5,
                color: Colors.grey.withOpacity(0.7),  // Darker - 70% opacity
                borderStrokeWidth: 1.5,
                borderColor: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        );
      }
      
      // Add frozen route stop markers
      if (frozenStops.isNotEmpty) {
        mapChildren.add(
          MarkerLayer(
            markers: frozenStops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value;
              final isFirst = index == 0;
              final isLast = index == frozenStops.length - 1;
              
              return Marker(
                point: stop.location,
                width: 35,
                height: 35,
                child: GestureDetector(
                  onTap: () {
                    // Show info but don't allow editing frozen stops
                    Get.snackbar(
                      'Reference Stop',
                      '${stop.name} (from ${routeController.currentDirection.value == 'up' ? 'DOWN' : 'UP'} route)',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isFirst
                          ? const Icon(Icons.home, color: Colors.white, size: 18)
                          : isLast
                              ? const Icon(Icons.school, color: Colors.white, size: 18)
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }

      // Add active route polyline
      if (routeController.routePolyline.isNotEmpty) {
        mapChildren.add(
          PolylineLayer(
            polylines: [
              Polyline(
                points: routeController.routePolyline,
                strokeWidth: 5.0,
                color: routeController.currentDirection.value == 'up' 
                    ? Colors.blue 
                    : Colors.orange,
                borderStrokeWidth: 2,
                borderColor: Colors.white,
              ),
            ],
          ),
        );
      }

      // Add stop markers (draggable)
      if (routeController.stops.isNotEmpty) {
        mapChildren.add(
          MarkerLayer(
            markers: routeController.stops.asMap().entries.map((entry) {
              int index = entry.key;
              Stop stop = entry.value;
              bool isFirst = index == 0;
              bool isLast = index == routeController.stops.length - 1;

              return Marker(
                width: 80.0,
                height: 80.0,
                point: stop.location,
                child: GestureDetector(
                  onTap: () => _showStopDetails(index, stop),
                  onLongPress: () {
                    // Enter reposition mode
                    setState(() {
                      _repositioningStopIndex = index;
                    });
                    Get.snackbar(
                      'Reposition Mode',
                      'Click anywhere on the map to move "${stop.name}" to that location',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.orange.withOpacity(0.9),
                      colorText: Colors.white,
                      mainButton: TextButton(
                        onPressed: () {
                          setState(() {
                            _repositioningStopIndex = null;
                          });
                          Get.closeAllSnackbars();
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _repositioningStopIndex == index
                              ? (isFirst ? Colors.green : isLast ? Colors.red : Colors.blue).withOpacity(0.7)
                              : (isFirst ? Colors.green : isLast ? Colors.red : Colors.blue),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: _repositioningStopIndex == index ? 8 : 4,
                              offset: Offset(0, _repositioningStopIndex == index ? 4 : 2),
                            ),
                          ],
                        ),
                        child: _repositioningStopIndex == index 
                            ? const Icon(
                                Icons.drag_indicator,
                                color: Colors.white,
                                size: 16,
                              )
                            : isFirst 
                                ? const Icon(Icons.home, color: Colors.white, size: 16)
                                : isLast 
                                    ? const Icon(Icons.school, color: Colors.white, size: 16)
                                    : Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                      ),
                      const SizedBox(height: 2),
                      if (_repositioningStopIndex != index)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              stop.name,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
      
      // Add waypoint markers (smaller, purple markers between stops)
      if (routeController.stops.isNotEmpty) {
        List<Marker> waypointMarkers = [];
        
        for (int i = 0; i < routeController.stops.length; i++) {
          final stop = routeController.stops[i];
          
          // Add markers for each waypoint in this stop's waypointsToNext list
          for (int j = 0; j < stop.waypointsToNext.length; j++) {
            final waypoint = stop.waypointsToNext[j];
            
            waypointMarkers.add(
              Marker(
                width: 60.0,
                height: 60.0,
                point: waypoint,
                child: GestureDetector(
                  onTap: () => _showWaypointOptions(i, j, stop),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_location_alt,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'WP',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
        
        if (waypointMarkers.isNotEmpty) {
          mapChildren.add(
            MarkerLayer(markers: waypointMarkers),
          );
        }
      }
      
      // Add marker for selected search result (before adding as stop)
      if (_selectedSearchResult != null) {
        mapChildren.add(
          MarkerLayer(
            markers: [
              Marker(
                width: 100.0,
                height: 100.0,
                point: LatLng(_selectedSearchResult!.latitude, _selectedSearchResult!.longitude),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_location,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Click map to add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.0,
                  onTap: (tapPosition, point) async {
                    // If in reposition mode, move the stop
                    if (_repositioningStopIndex != null) {
                      _updateStopLocation(_repositioningStopIndex!, point);
                      setState(() {
                        _repositioningStopIndex = null;
                      });
                      Get.closeAllSnackbars();
                      return;
                    }
                    
                    // If in waypoint mode, add waypoint
                    if (_isWaypointMode) {
                      await _addWaypointFromMap(point);
                      return;
                    }
                    
                    // Otherwise add stop when clicking on map
                    await _addStopFromMap(point);
                  },
                ),
                children: mapChildren,
              ),
            ),
          ),
        ],
      );
        }),
        
        // Search Bar Overlay
        _buildSearchOverlay(),
        
        // Repositioning Mode Banner
        if (_repositioningStopIndex != null)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.orange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Repositioning Stop ${_repositioningStopIndex! + 1} - Click map to place',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _repositioningStopIndex = null;
                          });
                          Get.closeAllSnackbars();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Waypoint Mode Banner
        if (_isWaypointMode)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.purple,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_location_alt, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Waypoint Mode - Click between stops to add route control points',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isWaypointMode = false;
                          });
                          Get.closeAllSnackbars();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  // Search Bar Widget
  Widget _buildSearchOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search for location (optional) or click map to add stop',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14),
                      ),
                      onChanged: (value) {
                        _debounceTimer?.cancel();
                        if (value.length < 3) {
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                          return;
                        }
                        
                        setState(() {
                          _isSearching = true;
                        });
                        
                        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _performSearch(value);
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchResults = [];
                          _selectedSearchResult = null;
                          _isSearching = false;
                        });
                      },
                    ),
                  if (_isSearching)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            
            // Search Results Dropdown
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.blue),
                      title: Text(
                        result.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        result.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSearchResult = result;
                          _searchController.text = result.name;
                          _searchResults = [];
                          _isSearching = false;
                        });
                        
                        // Move map to selected location
                        _mapController.move(
                          LatLng(result.latitude, result.longitude),
                          15,
                        );
                        
                        Get.snackbar(
                          '📍 Location Selected',
                          'Click on the map to add "${result.name}" as a stop',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.blue.withOpacity(0.9),
                          colorText: Colors.white,
                          duration: const Duration(seconds: 3),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Perform search using Nominatim
  Future<void> _performSearch(String query) async {
    try {
      final results = await OSRMService.autocomplete(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Widget _buildStopsPanel() {
    return Column(
      children: [
        // Panel Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.list, color: Colors.blue),
              const SizedBox(width: 12),
              Obx(() {
                return Text(
                  'Route Stops (${routeController.stops.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }),
              const Spacer(),
              const Tooltip(
                message: 'Use search bar to add stops',
                child: Icon(Icons.info_outline, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        
        // Stops List
        Expanded(
          child: Obx(() {
            if (routeController.stops.isEmpty) {
              return _buildEmptyStopsState();
            }

            return ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: routeController.stops.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final Stop item = routeController.stops.removeAt(oldIndex);
                routeController.stops.insert(newIndex, item);
                routeController.updateRoutePolyline();
                routeController.updateFirestore();
              },
              itemBuilder: (context, index) {
                final stop = routeController.stops[index];
                final isFirst = index == 0;
                final isLast = index == routeController.stops.length - 1;

                return _buildStopCard(index, stop, isFirst, isLast);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStopCard(int index, Stop stop, bool isFirst, bool isLast) {
    return Card(
      key: ValueKey('${stop.name}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isFirst
              ? Colors.green.withOpacity(0.3)
              : isLast
                  ? Colors.red.withOpacity(0.3)
                  : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isFirst
                ? Colors.green.withOpacity(0.1)
                : isLast
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isFirst
                    ? Colors.green
                    : isLast
                        ? Colors.red
                        : Colors.blue,
              ),
            ),
          ),
        ),
        title: Text(
          stop.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${stop.location.latitude.toStringAsFixed(5)}, '
                    '${stop.location.longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            if (isFirst) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'START',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (isLast) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'END',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit Button
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditStopDialog(index, stop),
              tooltip: 'Edit',
              color: Colors.blue,
            ),
            // Delete Button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _showDeleteConfirmation(index),
              tooltip: 'Delete',
              color: Colors.red,
            ),
            // Drag Handle
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: () {
          // Center map on this stop
          _mapController.move(stop.location, 16);
        },
      ),
    );
  }

  Widget _buildEmptyStopsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Stops Added',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click anywhere on the map to add a stop',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.blue, size: 32),
                      SizedBox(width: 16),
                      Icon(Icons.arrow_forward, color: Colors.grey),
                      SizedBox(width: 16),
                      Icon(Icons.add_location, color: Colors.green, size: 32),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Click Map → Stop Added',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Or search first for better location names',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return const SizedBox.shrink(); // No FABs needed now - search bar handles everything
  }

  // Add stop from map click (works with or without search)
  Future<void> _addStopFromMap(LatLng point) async {
    String stopName;
    double stopLat;
    double stopLng;
    
    if (_selectedSearchResult != null) {
      // Use search result if available
      stopName = _selectedSearchResult!.name;
      stopLat = _selectedSearchResult!.latitude;
      stopLng = _selectedSearchResult!.longitude;
    } else {
      // Direct map click - use reverse geocoding to get address
      stopLat = point.latitude;
      stopLng = point.longitude;
      
      // Show loading
      Get.snackbar(
        '🔍 Getting Location',
        'Looking up address...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        showProgressIndicator: true,
      );
      
      // Try to get address from coordinates
      final address = await OSRMService.reverseGeocode(point);
      stopName = address ?? 'Stop ${routeController.stops.length + 1} (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      
      Get.closeAllSnackbars();
    }
    
    // Show dialog to confirm/edit stop name
    final confirmed = await _showAddStopDialog(stopName, LatLng(stopLat, stopLng));
    
    if (confirmed != null && confirmed.isNotEmpty) {
      // Add the stop with confirmed name
      routeController.addStop(
        Stop(
          name: confirmed,
          location: LatLng(stopLat, stopLng),
        ),
      );
      
      // Clear selection
      setState(() {
        _searchController.clear();
        _selectedSearchResult = null;
        _searchResults = [];
      });
      
      // Show success message
      Get.snackbar(
        '✅ Stop Added',
        '$confirmed has been added to the route',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    
    // Update route
    await routeController.updateRoutePolyline();
    await routeController.updateFirestore();
    }
  }

  // Show dialog to add/confirm stop name
  Future<String?> _showAddStopDialog(String suggestedName, LatLng location) async {
    final TextEditingController nameController = TextEditingController(text: suggestedName);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_location, color: Colors.blue),
            SizedBox(width: 12),
            Text('Add Stop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a name for this stop:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                hintText: 'e.g., Main Gate, Bus Stand, etc.',
                prefixIcon: Icon(Icons.edit_location),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Coordinates:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              } else {
                Get.snackbar(
                  'Invalid Name',
                  'Please enter a stop name',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.9),
                  colorText: Colors.white,
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  // Add waypoint from map click
  Future<void> _addWaypointFromMap(LatLng point) async {
    final stops = routeController.stops;
    
    // Need at least 2 stops to add waypoints between them
    if (stops.length < 2) {
      Get.snackbar(
        '⚠️ Need More Stops',
        'Add at least 2 stops before adding waypoints',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    // Find which stop segment this waypoint belongs to
    int? targetStopIndex;
    double minDistance = double.infinity;
    
    for (int i = 0; i < stops.length - 1; i++) {
      final stop1 = stops[i];
      final stop2 = stops[i + 1];
      
      // Calculate distance from point to line segment
      final distance = _distanceToLineSegment(
        point,
        stop1.location,
        stop2.location,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        targetStopIndex = i;
      }
    }
    
    if (targetStopIndex == null) return;
    
    // Add waypoint to the closest stop's waypointsToNext list
    final targetStop = stops[targetStopIndex];
    final updatedWaypoints = List<LatLng>.from(targetStop.waypointsToNext);
    updatedWaypoints.add(point);
    
    // Update the stop with new waypoint
    final updatedStop = Stop(
      name: targetStop.name,
      location: targetStop.location,
      waypointsToNext: updatedWaypoints,
      isWaypoint: targetStop.isWaypoint,
    );
    
    routeController.stops[targetStopIndex] = updatedStop;
    
    // Update route
    await routeController.updateRoutePolyline();
    await routeController.updateFirestore();
    
    // Show success message
    Get.snackbar(
      '📍 Waypoint Added',
      'Added control point between ${targetStop.name} and ${stops[targetStopIndex + 1].name}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.purple.withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
    
    setState(() {});
  }
  
  // Calculate distance from point to line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final x0 = point.latitude;
    final y0 = point.longitude;
    final x1 = lineStart.latitude;
    final y1 = lineStart.longitude;
    final x2 = lineEnd.latitude;
    final y2 = lineEnd.longitude;
    
    final dx = x2 - x1;
    final dy = y2 - y1;
    
    if (dx == 0 && dy == 0) {
      // Line segment is a point
      final pdx = x0 - x1;
      final pdy = y0 - y1;
      return sqrt(pdx * pdx + pdy * pdy);
    }
    
    // Calculate projection parameter
    final t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy);
    
    double nearestX, nearestY;
    if (t < 0) {
      nearestX = x1;
      nearestY = y1;
    } else if (t > 1) {
      nearestX = x2;
      nearestY = y2;
    } else {
      nearestX = x1 + t * dx;
      nearestY = y1 + t * dy;
    }
    
    final pdx = x0 - nearestX;
    final pdy = y0 - nearestY;
    return sqrt(pdx * pdx + pdy * pdy);
  }

  // Update stop location when dragged
  void _updateStopLocation(int index, LatLng newLocation) async {
    final stop = routeController.stops[index];
    
    // Show loading indicator
    Get.snackbar(
      'Updating Stop',
      'Recalculating route...',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      showProgressIndicator: true,
    );
    
    // Get reverse geocoded name for new location
    String locationName = stop.name;
    try {
      final placeName = await OSRMService.reverseGeocode(newLocation);
      if (placeName != null && placeName.isNotEmpty) {
        locationName = placeName;
      }
    } catch (e) {
      locationName = '${newLocation.latitude.toStringAsFixed(5)}, ${newLocation.longitude.toStringAsFixed(5)}';
    }
    
    // Update the stop with new location
    final updatedStop = Stop(
      name: locationName,
      location: newLocation,
      waypointsToNext: stop.waypointsToNext,
      isWaypoint: stop.isWaypoint,
    );
    
    routeController.editStop(index, updatedStop);
    
    Get.closeAllSnackbars();
    Get.snackbar(
      'Stop Updated',
      'Route recalculated successfully',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _showWaypointOptions(int stopIndex, int waypointIndex, Stop stop) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_location_alt, color: Colors.purple, size: 28),
                SizedBox(width: 12),
                Text(
                  'Waypoint',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Between ${stop.name} and ${routeController.stops[stopIndex + 1].name}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.place, color: Colors.purple),
              title: const Text('Coordinates'),
              subtitle: Text(
                '${stop.waypointsToNext[waypointIndex].latitude.toStringAsFixed(6)}, '
                '${stop.waypointsToNext[waypointIndex].longitude.toStringAsFixed(6)}',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // Remove waypoint
                  final updatedWaypoints = List<LatLng>.from(stop.waypointsToNext);
                  updatedWaypoints.removeAt(waypointIndex);
                  
                  final updatedStop = Stop(
                    name: stop.name,
                    location: stop.location,
                    waypointsToNext: updatedWaypoints,
                    isWaypoint: stop.isWaypoint,
                  );
                  
                  routeController.stops[stopIndex] = updatedStop;
                  
                  // Update route
                  await routeController.updateRoutePolyline();
                  await routeController.updateFirestore();
                  
                  setState(() {});
                  
                  Get.snackbar(
                    '🗑️ Waypoint Removed',
                    'Control point has been deleted',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.withOpacity(0.9),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Waypoint'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStopDetails(int index, Stop stop) {
    // Show bottom sheet with stop details
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stop.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.numbers),
              title: const Text('Stop Number'),
              subtitle: Text('${index + 1}'),
            ),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Coordinates'),
              subtitle: Text(
                '${stop.location.latitude.toStringAsFixed(6)}, '
                '${stop.location.longitude.toStringAsFixed(6)}',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Enter reposition mode immediately
                      setState(() {
                        _repositioningStopIndex = index;
                      });
                      Get.snackbar(
                        'Reposition Mode',
                        'Click anywhere on the map to move "${stop.name}" to that location',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 4),
                        backgroundColor: Colors.orange.withOpacity(0.9),
                        colorText: Colors.white,
                        mainButton: TextButton(
                          onPressed: () {
                            setState(() {
                              _repositioningStopIndex = null;
                            });
                            Get.closeAllSnackbars();
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_location),
                    label: const Text('Move Stop'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditStopDialog(index, stop);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Rename'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(index);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStopDialog(int index, Stop stop) {
    final TextEditingController nameController = TextEditingController(text: stop.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                prefixIcon: Icon(Icons.edit_location),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coordinates',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stop.location.latitude.toStringAsFixed(6)}, '
                    '${stop.location.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                routeController.editStop(
                  index,
                  Stop(name: newName, location: stop.location),
                );
                Navigator.pop(context);
                Get.snackbar(
                  'Success',
                  'Stop updated successfully',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  colorText: Colors.green,
                );
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stop'),
        content: Text(
          'Are you sure you want to remove "${routeController.stops[index].name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              routeController.removeStop(index);
              Navigator.pop(context);
              Get.snackbar(
                'Deleted',
                'Stop removed from route',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.withOpacity(0.1),
                colorText: Colors.red,
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  
  // Bus Assignment Methods
  Future<void> _showBusAssignmentDialog() async {
    final busesSnapshot = await FirebaseFirestore.instance
        .collection('schooldetails')
        .doc(widget.schoolId)
        .collection('buses')
        .get();
    
    if (busesSnapshot.docs.isEmpty) {
      Get.snackbar(
        'No Buses Available',
        'Please add buses first before assigning them to routes',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }
    
    final selectedBusId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.blue),
            SizedBox(width: 12),
            Text('Assign Bus to Route'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a bus to assign to this route:'),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: busesSnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final busDoc = busesSnapshot.docs[index];
                    final busData = busDoc.data();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.directions_bus, color: Colors.blue),
                        title: Text('Bus ${busData['busNo']}'),
                        subtitle: Text(busData['busName'] ?? 'No name'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.of(context).pop(busDoc.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selectedBusId != null) {
      await _assignBus(selectedBusId);
    }
  }
  
  Future<void> _assignBus(String busId) async {
    try {
      // First, get the route document to fetch all stops
      final routeDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('routes')
          .doc(widget.routeId)
          .get();
      
      final routeData = routeDoc.data();
      if (routeData == null) {
        throw Exception('Route data not found');
      }
      
      // Get bus details to check if it's a test/simulator bus
      final busDoc = await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('buses')
          .doc(busId)
          .get();
      
      final busData = busDoc.data();
      final busNo = busData?['busNo'] ?? '';
      
      // Check if this is a simulator/test bus (contains "test" or "sim" in name)
      final isSimulatorBus = busNo.toLowerCase().contains('test') || 
                             busNo.toLowerCase().contains('sim');
      
      // Get the current direction's stops from the route
      final upStops = (routeData['upStops'] as List<dynamic>?) ?? [];
      final downStops = (routeData['downStops'] as List<dynamic>?) ?? [];
      final stopsToAssign = upStops.isNotEmpty ? upStops : downStops;
      
      // Only generate polyline for simulator/test buses to save storage costs
      List<Map<String, dynamic>>? polylineToAssign;
      if (isSimulatorBus && stopsToAssign.length >= 2) {
        try {
          // Parse stops to get locations and waypoints
          List<LatLng> stopLocations = [];
          List<LatLng> allWaypoints = [];
          
          for (var stopData in stopsToAssign) {
            final locationData = stopData['location'] as Map<String, dynamic>;
            final stopLoc = LatLng(
              (locationData['latitude'] as num).toDouble(),
              (locationData['longitude'] as num).toDouble(),
            );
            stopLocations.add(stopLoc);
            
            // Add custom waypoints if present
            final waypoints = (stopData['waypointsToNext'] as List<dynamic>?) ?? [];
            for (var wp in waypoints) {
              allWaypoints.add(LatLng(
                (wp['latitude'] as num).toDouble(),
                (wp['longitude'] as num).toDouble(),
              ));
            }
          }
          
          // Generate polyline using OSRM with all stops and waypoints
          final origin = stopLocations.first;
          final destination = stopLocations.last;
          final intermediateWaypoints = <LatLng>[
            ...stopLocations.sublist(1, stopLocations.length - 1),
            ...allWaypoints,
          ];
          
          final routeResult = await OSRMService.getDirections(
            origin: origin,
            destination: destination,
            waypoints: intermediateWaypoints,
          );
          
          if (routeResult != null && routeResult.polylinePoints.isNotEmpty) {
            polylineToAssign = routeResult.polylinePoints.map((point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            }).toList();
            print('🔧 [SIMULATOR BUS] Generated ${polylineToAssign.length} polyline points from ${stopLocations.length} stops');
          }
        } catch (e) {
          print('⚠️ Failed to generate polyline for simulator bus: $e');
        }
      }
      
      if (!isSimulatorBus) {
        print('🔧 [PRODUCTION BUS] Assigning ${stopsToAssign.length} stops only (no polyline for cost savings)');
      }
      
      await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('routes')
          .doc(widget.routeId)
          .update({
        'assignedBusId': busId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Prepare bus update data
      final busUpdateData = {
        'routeId': widget.routeId,
        'routeName': widget.routeName,
        'stoppings': stopsToAssign,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add polyline only for simulator buses
      if (isSimulatorBus && polylineToAssign != null && polylineToAssign.isNotEmpty) {
        busUpdateData['routePolyline'] = polylineToAssign;
      }
      
      await FirebaseFirestore.instance
          .collection('schooldetails')
          .doc(widget.schoolId)
          .collection('buses')
          .doc(busId)
          .update(busUpdateData);
      
      Get.snackbar(
        '✅ Bus Assigned',
        isSimulatorBus 
            ? 'Test bus assigned with road-following enabled'
            : 'Bus assigned with ${stopsToAssign.length} stops',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Failed to assign bus: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }
  
  Future<void> _removeBusAssignment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Remove Bus Assignment'),
          ],
        ),
        content: const Text('Are you sure you want to remove the bus assignment from this route?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Get current assigned bus ID
        final routeDoc = await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .doc(widget.routeId)
            .get();
        
        final routeData = routeDoc.data();
        final busId = routeData?['assignedBusId'] as String?;
        
        // Remove from route
        await FirebaseFirestore.instance
            .collection('schooldetails')
            .doc(widget.schoolId)
            .collection('routes')
            .doc(widget.routeId)
            .update({
          'assignedBusId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Remove from bus if exists
        if (busId != null) {
          await FirebaseFirestore.instance
              .collection('schooldetails')
              .doc(widget.schoolId)
              .collection('buses')
              .doc(busId)
              .update({
            'assignedRouteId': FieldValue.delete(),
            'routeName': FieldValue.delete(),
          });
        }
        
        Get.snackbar(
          '✅ Bus Removed',
          'Bus assignment has been removed from this route',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          '❌ Error',
          'Failed to remove bus assignment: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
        );
      }
    }
  }

  void _clearAllStops() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Stops'),
        content: const Text(
          'This will remove all stops from the route. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              routeController.stops.clear();
              routeController.updateRoutePolyline();
              routeController.updateFirestore();
              Navigator.pop(context);
              Get.snackbar(
                'Cleared',
                'All stops removed',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.withOpacity(0.1),
                colorText: Colors.red,
              );
            },
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
  }

  void _saveRoute() {
    routeController.updateFirestore();
    Get.snackbar(
      'Success',
      'Route saved successfully!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.1),
      colorText: Colors.green,
      icon: const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
