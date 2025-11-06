// route_management_controller.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class Stop {
  final String name;
  final LatLng location;

  Stop({required this.name, required this.location});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    };
  }

  factory Stop.fromMap(Map<String, dynamic> map) {
    final locationMap = map['location'] as Map<String, dynamic>;
    return Stop(
      name: map['name'],
      location: LatLng(locationMap['latitude'], locationMap['longitude']),
    );
  }
}

class RouteController extends GetxController {
  // Reactive list of stops.
  var stops = <Stop>[].obs;
  // Indicates whether the app is in "add stop" mode.
  var isAddingStop = false.obs;
  // Reactive list holding polyline points.
  var routePolyline = <LatLng>[].obs;

  late final String _uid;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _busId;

  // Store the last fetched OSRM route distance (in meters)
  var osrmRouteDistance = 0.0.obs;

  // Initialize with the bus ID and schoolId
  void init(String busId, {String? schoolId}) {
    _busId = busId;
    
    // Get schoolId from parameter, arguments, or throw error
    if (schoolId != null && schoolId.isNotEmpty) {
      _uid = schoolId;
    } else {
      final arguments = Get.arguments as Map<String, dynamic>?;
      _uid = arguments?['schoolId'] ?? '';
      if (_uid.isEmpty) {
        throw Exception('RouteController initialized without schoolId. Please pass schoolId.');
      }
    }

    // Log the schoolId for debugging purposes.
    if (kDebugMode) {
      print('Initialized RouteController with schoolId: $_uid');
    }
    _loadStops();
  }

  // Listen to Firestore for changes in stops.
  void _loadStops() {
    // Log the Firestore path for debugging.
    if (kDebugMode) {
      print('Fetching stops from: schooldetails/$_uid/buses/$_busId');
    }
    _firestore
        .collection('schooldetails')
        .doc(_uid)
        .collection('buses')
        .doc(_busId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('stoppings')) {
          final stopsData = data['stoppings'] as List<dynamic>;
          stops.value = stopsData
              .map((stop) => Stop.fromMap(stop as Map<String, dynamic>))
              .toList();
          // Update the polyline whenever stops change.
          updateRoutePolyline();
        }
      }
    });
  }

  // Update Firestore with the current stops.
  Future<void> updateFirestore() async {
    // <-- made public
    try {
      await _firestore
          .collection('schooldetails')
          .doc(_uid)
          .collection('buses')
          .doc(_busId)
          .update({
        'stoppings': stops.map((stop) => stop.toMap()).toList(),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to update route: $e');
    }
  }

  // Fetch the route polyline from OSRM.
  // NOTE: OSRM public endpoint may not work on hosted web due to CORS restrictions.
  // If polyline is not showing on production, consider using a proxy server or a CORS-friendly API.
  Future<void> updateRoutePolyline() async {
    if (stops.length < 2) {
      routePolyline.value = [];
      osrmRouteDistance.value = 0.0; // Reset distance
      return;
    }

    String coords = stops
        .map((stop) => '${stop.location.longitude},${stop.location.latitude}')
        .join(';');

    // Use HTTPS to avoid mixed content errors on production (web)
    String url =
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].length > 0) {
          List<dynamic> coordinates =
              data['routes'][0]['geometry']['coordinates'];
          routePolyline.value = coordinates
              .map((point) => LatLng(point[1] as double, point[0] as double))
              .toList();
          // Store the OSRM route distance (in meters)
          osrmRouteDistance.value =
              (data['routes'][0]['distance'] as num).toDouble();
        } else {
          routePolyline.value = [];
          osrmRouteDistance.value = 0.0;
          // Log error for debugging in production
          if (kDebugMode) {
            print('No route found in OSRM response: $data');
          }
          Get.snackbar('Route Error', 'No route found.');
        }
      } else {
        routePolyline.value = [];
        osrmRouteDistance.value = 0.0;
        // Log error for debugging in production
        if (kDebugMode) {
          print('Failed to fetch route. Status: ${response.statusCode}');
        }
        Get.snackbar('Route Error',
            'Failed to fetch route. Status: ${response.statusCode}');
      }
    } catch (e) {
      routePolyline.value = [];
      osrmRouteDistance.value = 0.0;
      // Log error for debugging in production
      if (kDebugMode) {
        print('Error fetching route: $e');
      }
      Get.snackbar('Route Error', 'Error fetching route: $e');
    }
  }

  // Calculate the total distance of the route.
  // Now returns the OSRM route distance if available, otherwise falls back to straight-line.
  double calculateDistance() {
    if (osrmRouteDistance.value > 0) {
      return osrmRouteDistance.value;
    }
    const Distance distance = Distance();
    double totalDistance = 0.0;

    for (int i = 0; i < stops.length - 1; i++) {
      totalDistance += distance.as(
        LengthUnit.Meter,
        stops[i].location,
        stops[i + 1].location,
      );
    }

    return totalDistance;
  }

  // Methods to add, remove, and edit stops.
  void addStop(Stop stop) {
    stops.add(stop);
    updateFirestore();
    updateRoutePolyline();
  }

  void removeStop(int index) {
    stops.removeAt(index);
    updateFirestore();
    updateRoutePolyline();
  }

  void editStop(int index, Stop newStop) {
    stops[index] = newStop;
    updateFirestore();
    updateRoutePolyline();
  }
}
