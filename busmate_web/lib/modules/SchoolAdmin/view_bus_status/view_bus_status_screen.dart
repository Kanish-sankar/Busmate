import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'view_bus_status_controller.dart';

class ViewBusStatusScreen extends StatelessWidget {
  final String schoolId;
  
  const ViewBusStatusScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ViewBusStatusController(schoolId: schoolId),
      tag: 'view_bus_status_$schoolId',
    );
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.map, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Live Bus Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refresh,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (controller.buses.isEmpty) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 24),
                  Text(
                    'No Buses Found',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No buses are configured for this school yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'How to add buses:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStep('1', 'Go to "Bus Management" from the dashboard'),
                        _buildStep('2', 'Click "Add Bus" button'),
                        _buildStep('3', 'Fill in bus details (Bus No, Driver, etc.)'),
                        _buildStep('4', 'Save the bus'),
                        const SizedBox(height: 8),
                        Text(
                          '💡 Once buses are added, they will appear here for real-time tracking.',
                          style: TextStyle(fontSize: 12, color: Colors.blue[800], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'School ID: ${controller.schoolId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show bus selection screen if no bus selected and not showing all buses
        return Obx(() {
          if (controller.selectedBus.value == null && !controller.showAllBusesOnMap.value) {
            return _buildBusSelectionScreen(controller);
          }
          
          return Row(
            children: [
              // Left Sidebar - Bus List
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Show Filter Tabs only when viewing all buses
                    Obx(() {
                      if (controller.showAllBusesOnMap.value) {
                        return _buildModernFilterTabs(controller);
                      }
                      return const SizedBox.shrink();
                    }),
                    // Bus List
                    Expanded(
                      child: _buildBusList(controller),
                    ),
                    // "View All Buses" button at the bottom
                    _buildViewAllBusesButton(controller),
                  ],
                ),
              ),
              // Right Side - Map View
              Expanded(
                child: _buildMapView(controller),
              ),
            ],
          );
        });
      }),
    );
  }
  
  Widget _buildModernFilterTabs(ViewBusStatusController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Buses',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildModernFilterChip(
                  'All',
                  controller.buses.length.toString(),
                  'all',
                  controller.filterStatus.value == 'all',
                  controller,
                  Icons.grid_view_rounded,
                )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => _buildModernFilterChip(
                  'Online',
                  controller.onlineBusCount.toString(),
                  'online',
                  controller.filterStatus.value == 'online',
                  controller,
                  Icons.check_circle,
                )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Obx(() => _buildModernFilterChip(
                  'Offline',
                  controller.offlineBusCount.toString(),
                  'offline',
                  controller.filterStatus.value == 'offline',
                  controller,
                  Icons.cancel,
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildModernFilterChip(
    String label,
    String count,
    String value,
    bool isSelected,
    ViewBusStatusController controller,
    IconData icon,
  ) {
    Color getColor() {
      if (value == 'online') return Colors.green;
      if (value == 'offline') return Colors.red;
      return Colors.blue;
    }

    final color = getColor();

    return InkWell(
      onTap: () => controller.setFilter(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBusList(ViewBusStatusController controller) {
    return Obx(() {
      final filteredBuses = controller.filteredBuses;
      
      if (filteredBuses.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No ${controller.filterStatus.value} buses',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: filteredBuses.length,
        itemBuilder: (context, index) {
          final bus = filteredBuses[index];
          return _buildBusListItem(bus, controller);
        },
      );
    });
  }
  
  Widget _buildBusListItem(BusWithLocation bus, ViewBusStatusController controller) {
    return Obx(() {
      final isSelected = controller.selectedBus.value?.id == bus.id;
      
      return InkWell(
        onTap: () => controller.selectBus(bus),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? bus.statusColor.withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? bus.statusColor : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: bus.statusColor.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bus Number & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bus.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    bus.statusIcon,
                    color: bus.statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.busNo,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bus.driverName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bus.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: bus.statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: bus.statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bus.statusText,
                        style: TextStyle(
                          color: bus.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Route Info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.route_rounded, size: 16, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bus.routeName,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.route, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bus.routeName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            // Live data
            if (bus.isOnline && bus.location != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(bus.location!.speed ?? 0).toStringAsFixed(1)} km/h',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.battery_std, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${bus.location!.batteryLevel ?? 0}%',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${bus.location!.timeSinceUpdate}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
    });
  }
  
  Widget _buildMapView(ViewBusStatusController controller) {
    return Obx(() {
      // Show all buses on map if flag is true, otherwise only online buses
      final showAllBuses = controller.showAllBusesOnMap.value;
      final onlineBuses = controller.buses.where((b) => b.isOnline).toList();
      final allBusesWithLocation = controller.buses.where((b) => b.location != null).toList();
      
      // Determine which buses to display
      final busesToShow = showAllBuses ? allBusesWithLocation : onlineBuses;
      
      if (busesToShow.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                showAllBuses ? 'No buses have location data' : 'No buses online',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                showAllBuses 
                    ? 'Waiting for buses to send location updates...'
                    : 'Waiting for buses to come online...',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      }
      
      // Calculate center point from buses to show
      final center = _calculateCenter(busesToShow);
      
      // Use higher zoom if only one bus is selected
      final selectedBus = controller.selectedBus.value;
      final displayCenter = selectedBus?.location != null && !showAllBuses
          ? LatLng(selectedBus!.location!.latitude, selectedBus.location!.longitude)
          : center;
      final zoomLevel = selectedBus != null && !showAllBuses 
          ? 16.0 
          : (busesToShow.length == 1 ? 15.0 : 13.0);
      
      return Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: displayCenter,
              initialZoom: zoomLevel,
              minZoom: 10,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jupenta.busmate',
              ),
              // Bus markers - show all buses or just selected/online
              MarkerLayer(
                markers: busesToShow.map((bus) {
                  final isSelected = controller.selectedBus.value?.id == bus.id;
                  return Marker(
                    point: LatLng(
                      bus.location!.latitude,
                      bus.location!.longitude,
                    ),
                    width: isSelected ? 100 : 80,
                    height: isSelected ? 100 : 80,
                    child: GestureDetector(
                      onTap: () => controller.selectBus(bus),
                      child: _buildBusMarker(bus, controller),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          // Selected bus details panel - show for both online and offline buses
          if (controller.selectedBus.value != null && 
              controller.selectedBus.value!.location != null &&
              !controller.showAllBusesOnMap.value)
            _buildSelectedBusPanel(controller.selectedBus.value!, controller),
        ],
      );
    });
  }
  
  Widget _buildBusMarker(BusWithLocation bus, ViewBusStatusController controller) {
    final isSelected = controller.selectedBus.value?.id == bus.id;
    final baseSize = isSelected ? 50.0 : 44.0;
    
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Uber/Ola style marker
        Transform.translate(
          offset: const Offset(0, -10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Drop shadow
              Transform.translate(
                offset: const Offset(0, 2),
                child: Container(
                  width: baseSize,
                  height: baseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Main marker circle
              Container(
                width: baseSize,
                height: baseSize,
                decoration: BoxDecoration(
                  color: bus.statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: Colors.white,
                    size: baseSize * 0.55,
                  ),
                ),
              ),
              // Pulsing ring for moving buses
              if (bus.isMoving)
                Container(
                  width: baseSize + 8,
                  height: baseSize + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: bus.statusColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
              // Direction indicator (small arrow at top)
              if (bus.location?.heading != null)
                Positioned(
                  top: -8,
                  child: Transform.rotate(
                    angle: (bus.location!.heading! * 3.14159) / 180,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: bus.statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Bus number badge
        Positioned(
          top: baseSize + 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bus.statusColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              bus.busNo,
              style: TextStyle(
                color: bus.statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        // Speed indicator for moving buses
        if (bus.isMoving && bus.location?.speed != null && bus.location!.speed! > 5)
          Positioned(
            bottom: baseSize + 25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '${bus.location!.speed!.toInt()} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildSelectedBusPanel(BusWithLocation bus, ViewBusStatusController controller) {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(bus.statusIcon, color: bus.statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.busNo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: bus.statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: bus.statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            bus.isOnline ? bus.statusText : 'Offline - Last Known Location',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: bus.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.selectBus(null),
                    iconSize: 20,
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.person, 'Driver', bus.driverName),
              _buildDetailRow(Icons.route, 'Route', bus.routeName),
              if (bus.location != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                if (!bus.isOnline) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bus is offline. Showing last known location from ${bus.location!.timeSinceUpdate}.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow(
                  Icons.speed,
                  'Speed',
                  '${(bus.location!.speed ?? 0).toStringAsFixed(1)} km/h',
                ),
                _buildDetailRow(
                  Icons.explore,
                  'Heading',
                  '${(bus.location!.heading ?? 0).toStringAsFixed(0)}°',
                ),
                _buildDetailRow(
                  Icons.battery_std,
                  'Battery',
                  '${bus.location!.batteryLevel ?? 0}%',
                ),
                _buildDetailRow(
                  Icons.schedule,
                  bus.isOnline ? 'Last Update' : 'Last Seen',
                  bus.location!.timeSinceUpdate,
                ),
                if (bus.location!.currentStop != null && bus.location!.currentStop!.isNotEmpty)
                  _buildDetailRow(
                    Icons.place,
                    'Current Stop',
                    bus.location!.currentStop!,
                  ),
                if (bus.location!.nextStop != null && bus.location!.nextStop!.isNotEmpty)
                  _buildDetailRow(
                    Icons.next_plan,
                    'Next Stop',
                    bus.location!.nextStop!,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBusSelectionScreen(ViewBusStatusController controller) {
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Compact Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus, size: 32, color: Colors.blue[600]),
                const SizedBox(width: 16),
                const Text(
                  'Select a Bus to Track',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Bus Grid
          Expanded(
            child: Obx(() {
              final buses = controller.buses;
              
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: buses.length,
                itemBuilder: (context, index) {
                  final bus = buses[index];
                  return _buildBusSelectionCard(bus, controller);
                },
              );
            }),
          ),
          
          const SizedBox(height: 16),
          
          // "View All Buses" Button at bottom
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            child: ElevatedButton.icon(
              onPressed: () => controller.showAllBuses(),
              icon: const Icon(Icons.map, size: 22),
              label: const Text(
                'View All Buses on Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildBusSelectionCard(BusWithLocation bus, ViewBusStatusController controller) {
    return InkWell(
      onTap: () {
        controller.selectBus(bus);
        controller.showAllBusesOnMap.value = false;
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bus.isOnline ? bus.statusColor.withOpacity(0.3) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bus.statusIcon,
              size: 40,
              color: bus.statusColor,
            ),
            const SizedBox(height: 12),
            Text(
              bus.busNo,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bus.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bus.statusColor.withOpacity(0.5)),
              ),
              child: Text(
                bus.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: bus.statusColor,
                ),
              ),
            ),
            if (bus.isOnline && bus.location != null) ...[
              const SizedBox(height: 8),
              Text(
                bus.location!.timeSinceUpdate,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (!bus.isOnline && bus.location != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last seen: ${bus.location!.timeSinceUpdate}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildViewAllBusesButton(ViewBusStatusController controller) {
    return Obx(() {
      final showingAll = controller.showAllBusesOnMap.value;
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            if (showingAll) {
              controller.showAllBusesOnMap.value = false;
              controller.selectedBus.value = null;
            } else {
              controller.showAllBuses();
            }
          },
          icon: Icon(showingAll ? Icons.close : Icons.grid_view, size: 20),
          label: Text(
            showingAll ? 'Close All Buses View' : 'View All Buses',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: showingAll ? Colors.orange : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      );
    });
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  LatLng _calculateCenter(List<BusWithLocation> buses) {
    if (buses.isEmpty) return const LatLng(11.0168, 76.9558); // Coimbatore default
    
    double sumLat = 0;
    double sumLng = 0;
    int count = 0;
    
    for (final bus in buses) {
      if (bus.location != null) {
        sumLat += bus.location!.latitude;
        sumLng += bus.location!.longitude;
        count++;
      }
    }
    
    if (count == 0) return const LatLng(11.0168, 76.9558);
    
    return LatLng(sumLat / count, sumLng / count);
  }
}


