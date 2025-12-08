import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:busmate_web/services/osrm_service.dart';

/// Dialog for adding a new bus stop to a route
/// Supports search-first approach with map adjustment
class AddStopDialog extends StatefulWidget {
  final Function(BusStop) onStopAdded;
  final LatLng? initialLocation; // Optional pre-selected location

  const AddStopDialog({
    super.key,
    required this.onStopAdded,
    this.initialLocation,
  });

  @override
  State<AddStopDialog> createState() => _AddStopDialogState();
}

class _AddStopDialogState extends State<AddStopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _mapController = MapController();
  
  List<LocationSuggestion> _suggestions = [];
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isSearching = false;
  
  int _step = 1; // 1: Search, 2: Confirm on Map, 3: Add Details
  
  // Debouncing to prevent API spam
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 800); // Wait 800ms after user stops typing

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _step = 2;
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.add_location_alt, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Add Bus Stop',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Step Indicator
            _buildStepIndicator(),
            const SizedBox(height: 24),
            
            // Content based on step
            Expanded(
              child: _step == 1
                  ? _buildSearchStep()
                  : _step == 2
                      ? _buildMapConfirmationStep()
                      : _buildDetailsStep(),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Step indicator showing current progress
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(1, 'Search', _step >= 1),
        _buildStepLine(_step >= 2),
        _buildStepCircle(2, 'Confirm', _step >= 2),
        _buildStepLine(_step >= 3),
        _buildStepCircle(3, 'Details', _step >= 3),
      ],
    );
  }

  Widget _buildStepCircle(int stepNumber, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blue : Colors.grey[300],
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color: isActive ? Colors.blue : Colors.grey[300],
      ),
    );
  }

  /// Step 1: Search for location
  Widget _buildSearchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search for bus stop location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Type a landmark, street name, or area to find the stop location',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        
        // Search Field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'e.g., "Park Street", "T Nagar", "School Gate"',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 16),
        
        // Search Results
        Expanded(
          child: _buildSearchResults(),
        ),
        
        // OR Manual Selection
        const Divider(height: 32),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.map),
            label: const Text('Or select location on map manually'),
            onPressed: () {
              setState(() {
                _step = 2;
                _selectedLocation = const LatLng(13.0827, 80.2707); // Default Chennai
              });
            },
          ),
        ),
      ],
    );
  }

  /// Search results list
  Widget _buildSearchResults() {
    if (_suggestions.isEmpty) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Start typing to search',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Search Tips:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSearchTip('"Railway Station, Coimbatore"'),
                    _buildSearchTip('"Bus Stand, Irugur"'),
                    _buildSearchTip('"Gandhi Market, Chennai"'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(suggestion.name),
          subtitle: Text(suggestion.address),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
  
  Widget _buildSearchTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.blue[700])),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.blue[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2: Confirm location on map with drag adjustment
  Widget _buildMapConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm exact location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (_selectedAddress != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAddress!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Drag the marker to adjust the exact pickup point',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        
        // Map View
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation ?? const LatLng(13.0827, 80.2707),
                  initialZoom: 16,
                  onTap: (_, point) {
                    // Use clicked location directly - no snapping
                    // This allows placing stops on either side of the road
                    setState(() => _selectedLocation = point);
                  },
                ),
                children: [
                  // OpenStreetMap Tiles
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jupenta.busmate',
                  ),
                  
                  // Draggable Marker
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              // Allow dragging marker
                              // Note: Simplified drag logic - moves marker by delta in lat/lng
                              final newLat = _selectedLocation!.latitude + (details.delta.dy * -0.00001);
                              final newLng = _selectedLocation!.longitude + (details.delta.dx * 0.00001);
                              setState(() => _selectedLocation = LatLng(newLat, newLng));
                            },
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Drag to adjust',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Location Coordinates (for reference)
        if (_selectedLocation != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Coordinates: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
              '${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
      ],
    );
  }

  /// Step 3: Add stop details (name, notes)
  Widget _buildDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add stop details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          
          // Stop Name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Stop Name *',
              hintText: 'e.g., "Park Street Stop", "Near Temple"',
              prefixIcon: const Icon(Icons.label),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a stop name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Address (read-only)
          TextFormField(
            initialValue: _selectedAddress ?? 'Custom location',
            decoration: InputDecoration(
              labelText: 'Address',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            readOnly: true,
          ),
          const SizedBox(height: 16),
          
          // Notes (optional)
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Any special instructions for drivers',
              prefixIcon: const Icon(Icons.note),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Action buttons at bottom
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_step > 1)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Back'),
          ),
        const SizedBox(width: 8),
        
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        
        ElevatedButton(
          onPressed: _canProceed() ? _handleNext : null,
          child: Text(_step == 3 ? 'Add Stop' : 'Next'),
        ),
      ],
    );
  }

  bool _canProceed() {
    if (_step == 1) return _selectedLocation != null;
    if (_step == 2) return _selectedLocation != null;
    if (_step == 3) return _nameController.text.trim().isNotEmpty;
    return false;
  }

  void _handleNext() {
    if (_step == 3) {
      if (_formKey.currentState!.validate()) {
        final stop = BusStop(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _selectedAddress ?? 'Custom location',
        );
        widget.onStopAdded(stop);
        Get.back();
      }
    } else {
      setState(() => _step++);
      if (_step == 3) {
        // Auto-fill name from address if available
        if (_selectedAddress != null && _nameController.text.isEmpty) {
          _nameController.text = _selectedAddress!.split(',').first;
        }
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Show loading immediately
    setState(() => _isSearching = true);

    // Start new timer - only execute search after user stops typing for 800ms
    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(query);
    });
  }
  
  Future<void> _performSearch(String query) async {
    try {
      
      // Use Nominatim (OpenStreetMap) Autocomplete API - FREE!
      final results = await OSRMService.autocomplete(
        query,
        location: const LatLng(13.0827, 80.2707), // Chennai as location bias
        radius: 50000, // 50km radius
      );
      
      
      if (!mounted) return; // Check if widget still mounted
      
      setState(() {
        _suggestions = results.map((result) => LocationSuggestion(
          name: result.name,
          address: result.address,
          latitude: result.latitude,
          longitude: result.longitude,
        )).toList();
        _isSearching = false;
      });
      
      // Show helpful message if few or no results
      if (mounted) {
        if (results.isEmpty) {
          Get.snackbar(
            '❌ No Results Found',
            'OpenStreetMap has no data for "$query".\nTry: Add city name like "Irugur, Coimbatore"\nOr use "Select on map manually" below.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.withOpacity(0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
        } else if (results.length <= 2) {
          Get.snackbar(
            '💡 Limited Results (${results.length})',
            'Only ${results.length} match(es) in OpenStreetMap.\nTry: "$query, Coimbatore" for more options.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.blue.withOpacity(0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isSearching = false);
      
      // Don't show error snackbar for every failed request (rate limiting)
      if (!e.toString().contains('Failed to fetch')) {
        Get.snackbar(
          'Search Error',
          'Please wait a moment and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _selectSuggestion(LocationSuggestion suggestion) async {
    final originalLocation = LatLng(suggestion.latitude, suggestion.longitude);
    
    // Use the location directly from search - it's already accurate
    // No need to snap, as OLA Maps provides precise coordinates
    setState(() {
      _selectedLocation = originalLocation;
      _selectedAddress = suggestion.address;
      _step = 2;
    });
    
    // Move map to selected location
    _mapController.move(_selectedLocation!, 16);
    
    // Info message
    Get.snackbar(
      '📍 Location Selected',
      'You can adjust the exact position on the map if needed',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue.withOpacity(0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

}

/// Model for location search suggestions
class LocationSuggestion {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  LocationSuggestion({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// Model for bus stop
class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String? notes;

  BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.notes,
  });
}
