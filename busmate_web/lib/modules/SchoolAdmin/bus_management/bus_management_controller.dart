import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bus_model.dart';

class BusController extends GetxController {
  var buses = <Bus>[].obs;
  var isLoading = false.obs;
  var searchText = ''.obs;
  var busStatuses = <String, BusStatusModel>{}.obs; // Map to store bus statuses
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  late String schoolId;

  // Update to use buses as a subcollection under schools
  CollectionReference get busCollection =>
      firestore.collection('schools').doc(schoolId).collection('buses');

  CollectionReference get busStatusCollection =>
      firestore.collection('bus_status');

  @override
  void onInit() {
    super.onInit();
    // Get schoolId from arguments only
    final arguments = Get.arguments as Map<String, dynamic>?;
    schoolId = arguments?['schoolId'] ?? '';
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

  void fetchBuses() {
    isLoading.value = true;
    busCollection.snapshots().listen((QuerySnapshot snapshot) {
      buses.value = snapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();
      isLoading.value = false;
    });
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
        'students': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to assign student to bus: $e');
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

  // Filter buses based on search text.
  List<Bus> get filteredBuses {
    if (searchText.value.isEmpty) return buses;
    return buses.where((bus) => bus.busNo.contains(searchText.value)).toList();
  }
}
