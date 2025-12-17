import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service class for OpenStreetMap & OSRM integration
/// Uses FREE services:
/// - Nominatim (OpenStreetMap) for geocoding/autocomplete
/// - OSRM for routing and directions
/// - No API keys required!
class OlaMapsService {
  static const String _baseUrl = 'https://api.olamaps.io';
  
  /// Autocomplete search for places using Nominatim (OpenStreetMap)
  /// Returns list of location suggestions based on user query
  /// FREE - No API key required!
  static Future<List<PlaceSuggestion>> autocomplete(String query, {
    LatLng? location,
    int? radius,
  }) async {
    try {
      if (query.isEmpty || query.length < 2) {
        return [];
      }

      // Use Nominatim (OpenStreetMap's geocoding service) - completely free!
      final params = {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '50', // Increased limit for more results
        'countrycodes': 'in', // Restrict to India for better results
        'dedupe': '0', // Don't dedupe - we want all matches
        'extratags': '1', // Include extra place tags
        'namedetails': '1', // Include name translations
      };
      
      // Add location bias if provided (viewbox parameter)
      if (location != null) {
        final lat = location.latitude;
        final lng = location.longitude;
        const offset = 0.5; // ~50km radius
        // Format: viewbox=<x1>,<y1>,<x2>,<y2> (left,top,right,bottom)
        params['viewbox'] = '${lng - offset},${lat + offset},${lng + offset},${lat - offset}';
        params['bounded'] = '0'; // Still allow results outside viewbox
      }

      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: params,
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'BusmateApp/1.0', // Nominatim requires User-Agent
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        
        // If no results with India restriction, try without it
        if (results.isEmpty && params.containsKey('countrycodes')) {
          params.remove('countrycodes');
          
          final retryUri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
            queryParameters: params,
          );
          
          final retryResponse = await http.get(
            retryUri,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'BusmateApp/1.0',
            },
          );
          
          if (retryResponse.statusCode == 200) {
            final retryResults = jsonDecode(retryResponse.body) as List<dynamic>;
            
            if (retryResults.isNotEmpty) {
              return retryResults.map((result) {
                final displayName = result['display_name'] ?? '';
                final addressParts = displayName.split(',');
                final mainName = addressParts.isNotEmpty ? addressParts[0].trim() : displayName;
                
                return PlaceSuggestion(
                  placeId: result['place_id']?.toString() ?? result['osm_id']?.toString() ?? '',
                  name: mainName,
                  address: displayName,
                  latitude: double.tryParse(result['lat']?.toString() ?? '0') ?? 0.0,
                  longitude: double.tryParse(result['lon']?.toString() ?? '0') ?? 0.0,
                );
              }).toList();
            }
          }
        }
        
        if (results.isEmpty) {
          return [];
        }
        
        return results.map((result) {
          final displayName = result['display_name'] ?? '';
          final addressParts = displayName.split(',');
          final mainName = addressParts.isNotEmpty ? addressParts[0].trim() : displayName;
          
          return PlaceSuggestion(
            placeId: result['place_id']?.toString() ?? result['osm_id']?.toString() ?? '',
            name: mainName,
            address: displayName,
            latitude: double.tryParse(result['lat']?.toString() ?? '0') ?? 0.0,
            longitude: double.tryParse(result['lon']?.toString() ?? '0') ?? 0.0,
          );
        }).toList();
      } else {
        throw Exception('Nominatim API Error ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }
  
  /// Get place details by place ID
  ///
  /// NOTE: Previously this used Ola endpoints with a client-side API key.
  /// That has been removed for production hardening. This method is currently
  /// unused in the web app; return null to avoid shipping secrets.
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    return null;
  }
  
  /// Reverse geocoding - get address from coordinates using Nominatim
  /// FREE - No API key required!
  static Future<String?> reverseGeocode(LatLng location) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': location.latitude.toString(),
          'lon': location.longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );
      
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'BusmateApp/1.0',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get road-snapped route using OSRM (free, open-source)
  /// This creates proper road-aware routes instead of straight lines
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    try {
      // Build coordinates string: origin, waypoints, destination
      List<String> coords = [];
      coords.add('${origin.longitude},${origin.latitude}');
      
      if (waypoints != null && waypoints.isNotEmpty) {
        for (var point in waypoints) {
          coords.add('${point.longitude},${point.latitude}');
        }
      }
      
      coords.add('${destination.longitude},${destination.latitude}');
      
      // Use OSRM for road routing (free and reliable)
      String coordsStr = coords.join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsStr?overview=full&geometries=geojson&steps=true'
      );
      
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] != 'Ok') {
          return null;
        }
        
        final routes = data['routes'] as List? ?? [];
        
        if (routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final legs = route['legs'] as List? ?? [];
          
          // Extract polyline points from GeoJSON coordinates
          List<LatLng> polylinePoints = [];
          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            for (var coord in coordinates) {
              // GeoJSON format is [lng, lat]
              polylinePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
          
          // Calculate total distance and duration
          int totalDistance = 0;
          int totalDuration = 0;
          for (var leg in legs) {
            totalDistance += (leg['distance'] as num?)?.toInt() ?? 0;
            totalDuration += (leg['duration'] as num?)?.toInt() ?? 0;
          }
          
          
          return DirectionsResult(
            polylinePoints: polylinePoints,
            distanceMeters: totalDistance,
            durationSeconds: totalDuration,
            distanceText: '${(totalDistance / 1000).toStringAsFixed(2)} km',
            durationText: '${(totalDuration / 60).toStringAsFixed(0)} min',
          );
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Snap a point to nearest road using OSRM
  /// This prevents stops from being placed on wrong side of road
  static Future<LatLng?> snapToRoad(LatLng point, {int radiusMeters = 50}) async {
    try {
      // Use OSRM nearest service to snap point to road
      final uri = Uri.parse(
        'https://router.project-osrm.org/nearest/v1/driving/${point.longitude},${point.latitude}?number=1'
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok') {
          final waypoints = data['waypoints'] as List? ?? [];
          if (waypoints.isNotEmpty) {
            final location = waypoints[0]['location'];
            // OSRM returns [lng, lat]
            final snapped = LatLng(location[1].toDouble(), location[0].toDouble());
            
            return snapped;
          }
        }
      }
      
      return point; // Return original if snapping fails
    } catch (e) {
      return point;
    }
  }
  
  /// Get distance matrix for multiple origins and destinations
  static Future<DistanceMatrixResult?> getDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
  }) async {
    // This web project uses Ola distance matrix via the authenticated Cloud Function
    // in OlaDistanceMatrixService to keep the API key server-side.
    return null;
  }
}

/// Model classes for API responses

class PlaceSuggestion {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
  });
}

class DistanceMatrixResult {
  final List<DistanceElement> elements;

  DistanceMatrixResult({required this.elements});
}

class DistanceElement {
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;

  DistanceElement({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
  });
}
