import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';

class PlacePrediction {
  final String description;
  final String placeId;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.description,
    required this.placeId,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final sf = json['structured_formatting'] as Map<String, dynamic>?;
    return PlacePrediction(
      description: json['description'] as String,
      placeId: json['place_id'] as String,
      mainText: sf?['main_text'] as String?,
      secondaryText: sf?['secondary_text'] as String?,
    );
  }
}

class LocationSearchField extends StatelessWidget {
  final void Function(String name, LatLng location) onLocationSelected;
  final TextEditingController searchController = TextEditingController();

  // Firebase Functions URL
  static const String _baseUrl =
      'https://us-central1-busmate-b80e8.cloudfunctions.net';

  LocationSearchField({super.key, required this.onLocationSelected});

  Future<List<PlacePrediction>> _getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    final uri = Uri.parse('$_baseUrl/autocomplete').replace(
      queryParameters: {
        'input': input,
        'sessiontoken': sessionToken,
      },
    );

    try {
      debugPrint('Calling autocomplete API: ${uri.toString()}');
      final resp = await http.get(uri);

      debugPrint('Autocomplete response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        debugPrint('Autocomplete response status: ${data['status']}');

        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList();
        } else {
          debugPrint(
              'Autocomplete API error: ${data['error_message'] ?? data['status']}');
        }
      }
    } catch (e) {
      debugPrint('Autocomplete proxy error: $e');
    }
    return [];
  }

  Future<LatLng?> _getLatLngFromPlaceId(String placeId) async {
    final uri = Uri.parse('$_baseUrl/geocode').replace(
      queryParameters: {'place_id': placeId},
    );

    try {
      debugPrint('Calling geocode API: ${uri.toString()}');
      final resp = await http.get(uri);

      debugPrint('Geocode response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        debugPrint('Geocode API response: ${resp.body}');

        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;
          final geometry = results[0]['geometry'] as Map<String, dynamic>?;

          if (geometry != null) {
            final location = geometry['location'] as Map<String, dynamic>?;

            if (location != null &&
                location.containsKey('lat') &&
                location.containsKey('lng')) {
              final lat = (location['lat'] as num).toDouble();
              final lng = (location['lng'] as num).toDouble();
              debugPrint('Location found: $lat, $lng');
              return LatLng(lat, lng);
            } else {
              debugPrint('Invalid location data: $location');
            }
          } else {
            debugPrint('No geometry in results: $results');
          }
        } else {
          final errorMsg =
              data['error_message'] ?? data['status'] ?? 'Unknown error';
          debugPrint('Geocode API error: $errorMsg');
        }
      }
    } catch (e) {
      debugPrint('Geocode proxy error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TypeAheadField<PlacePrediction>(
        controller: searchController,
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search for location...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
              ),
            ),
          );
        },
        debounceDuration: const Duration(milliseconds: 500),
        suggestionsCallback: _getPlacePredictions,
        itemBuilder: (context, suggestion) {
          return ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(suggestion.mainText ?? suggestion.description),
            subtitle: Text(suggestion.secondaryText ?? ''),
          );
        },
        onSelected: (suggestion) async {
          searchController.text = suggestion.description;
          final location = await _getLatLngFromPlaceId(suggestion.placeId);
          if (location != null) {
            onLocationSelected(suggestion.description, location);
            searchController.clear();
          } else {
            Get.snackbar(
              'Error',
              'Could not fetch coordinates for this location.',
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
              duration: const Duration(seconds: 3),
            );
          }
        },
        loadingBuilder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        emptyBuilder: (context) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No locations found.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        errorBuilder: (context, error) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
