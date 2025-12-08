import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bus_model.dart';

class BusController extends GetxController {
  var buses = <Bus>[].obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  var selectedFilter = 'all'.obs; // Filter state
  var busStatuses = <String, BusStatusModel>{}.obs; // Map to store bus statuses
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String schoolId;

  // Update to use buses as a subcollection under schooldetails
  CollectionReference get busCollection =>
      firestore.collection('schooldetails').doc(schoolId).collection('buses');

  CollectionReference get busStatusCollection =>
      firestore.collection('bus_status');
  
  // Filtered buses based on search and filter
  List<Bus> get filteredBuses {
    var filtered = buses.where((bus) {
      // Search filter
      final matchesSearch = searchText.value.isEmpty ||
          bus.busNo.toLowerCase().contains(searchText.value.toLowerCase()) ||
          bus.busVehicleNo.toLowerCase().contains(searchText.value.toLowerCase());
      
      if (!matchesSearch) return false;
      
      // Status filter
      switch (selectedFilter.value) {
        case 'needs_setup':
          return !bus.hasDriver || !bus.hasRoute;
        case 'all':
        default:
          return true;
      }
    }).toList();
    
    return filtered;
  }

  @override
  void onInit() {
    super.onInit();
    // Get schoolId from arguments (set by screen constructor)
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('schoolId')) {
      schoolId = arguments['schoolId'];
    }
    // schoolId should be set by the screen before calling onInit
    // If not set, throw an error to catch configuration issues
    if (schoolId.isEmpty) {
      throw Exception('BusController initialized without schoolId. Please pass schoolId to BusManagementScreen.');
    }
    fetchBuses();
  }

  Future<void> updateBusDriver(
      String busId, String driverId, String driverName) async {
    try {
      final busDoc = busCollection.doc(busId);
      await busDoc.update({
        'driverId': driverId,
        'driverName': driverName,
      });
      Get.snackbar('Success', 'Bus updated with driver information');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update bus with driver info: $e');
    }
  }

  void fetchBuses() async {
    print('🚌 Fetching buses for schoolId: $schoolId');
    isLoading.value = true;
    try {
      // ONE-TIME READ instead of real-time listener
      final snapshot = await busCollection.get();
      print('✅ Received ${snapshot.docs.length} buses');
      buses.value = snapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();
      isLoading.value = false;
    } catch (error) {
      print('❌ Error fetching buses: $error');
      isLoading.value = false;
      Get.snackbar(
        '❌ Error',
        'Failed to load buses: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void fetchBusStatus(String busId) {
    try {
      busStatusCollection.doc(busId).snapshots().listen((doc) {
        if (doc.exists) {
          final status = BusStatusModel.fromDocument(doc);
          busStatuses[busId] =
              status; // Update the map with the real-time status
          update(); // Trigger UI updates
        }
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch bus status: $e');
    }
  }

  Future<void> addBus(Bus bus) async {
    try {
      // Generate a new document ID if the bus ID is empty
      final String docId = bus.id.isEmpty ? busCollection.doc().id : bus.id;
      await busCollection.doc(docId).set(bus.toMap());
      await busStatusCollection.doc(docId).set(BusStatusModel(
            busId: docId,
            currentLocation: {},
            latitude: 0.0,
            longitude: 0.0,
          ).toMap());
      Get.snackbar('Success', 'Bus added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add bus: $e');
    }
  }

  Future<void> updateBus(String id, Bus bus) async {
    try {
      await busCollection.doc(id).update(bus.toMap());
      Get.snackbar('Success', 'Bus updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update bus: $e');
    }
  }

  Future<void> deleteBus(String id) async {
    try {
      await busCollection.doc(id).delete();
      Get.snackbar('Success', 'Bus deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete bus: $e');
    }
  }

  Future<void> addStudentToBus(String busId, String studentId) async {
    try {
      final busDoc = busCollection.doc(busId);
      await busDoc.update({
        'assignedStudents': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to assign student to bus: $e');
    }
  }

  Future<void> removeStudentFromBus(String busId, String studentId) async {
    try {
      final busDoc = busCollection.doc(busId);
      await busDoc.update({
        'assignedStudents': FieldValue.arrayRemove([studentId]),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove student from bus: $e');
    }
  }

  Future<void> updateBusStatus(String id, BusStatusModel status) async {
    try {
      await busStatusCollection.doc(id).update(status.toMap());
      Get.snackbar('Success', 'Bus status updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update bus status: $e');
    }
  }
}
