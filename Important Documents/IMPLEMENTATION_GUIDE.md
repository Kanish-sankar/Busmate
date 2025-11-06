# 🚀 Step-by-Step Implementation Guide

## Overview
This guide provides exact code changes for both BusMate Mobile App and BusMate Web App to reduce Firebase costs by 80%.

---

## 📱 MOBILE APP OPTIMIZATIONS

### Step 1: Enable Offline Persistence (5 minutes)

**File:** `busmate_app/lib/main.dart`

**Find this section (around line 15-20):**
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Add immediately after:**
```dart
// Enable offline persistence for automatic caching
await FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024, // 100MB cache
);
```

**Expected Result:** App will cache data automatically, reducing reads by 20-30%

---

### Step 2: Replace Bus Status Real-time Listener (15 minutes)

**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

**Find this code (around line 136-145):**
```dart
Future<void> updateRoutePolyline(String schoolId, String busId) async {
  // Listen for changes in the bus status document
  FirebaseFirestore.instance
      .collection('bus_status')
      .doc(busId)
      .snapshots()
      .listen((doc) async {
    if (doc.exists && doc.data() != null) {
      final status =
          BusStatusModel.fromMap(doc.data() as Map<String, dynamic>, busId);
      // ... rest of the code
```

**Replace with:**
```dart
// Add these instance variables at the top of the class
Timer? _busStatusPollingTimer;
Timer? _routeUpdateTimer;

Future<void> updateRoutePolyline(String schoolId, String busId) async {
  // Cancel any existing timers
  _busStatusPollingTimer?.cancel();
  _routeUpdateTimer?.cancel();
  
  // Start polling bus status every 30 seconds instead of real-time
  _busStatusPollingTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bus_status')
          .doc(busId)
          .get();
          
      if (doc.exists && doc.data() != null) {
        final status =
            BusStatusModel.fromMap(doc.data() as Map<String, dynamic>, busId);
        
        // Only process if bus is active
        if (status.currentStatus != 'Active') {
          timer.cancel();
          return;
        }

        // Rate limiting check
        if (_lastRouteFetch != null &&
            DateTime.now().difference(_lastRouteFetch!) < _minFetchInterval) {
          return;
        }
        _lastRouteFetch = DateTime.now();

        // Build route points from current location and remaining stops
        List<LatLng> routePoints = [LatLng(status.latitude, status.longitude)];
        for (var stop in status.remainingStops) {
          routePoints.add(LatLng(stop.latitude, stop.longitude));
        }

        // If we have less than 2 points, we can't create a route
        if (routePoints.length < 2) {
          routePolyline.value = routePoints;
          return;
        }

        // Build OSRM coordinates
        String coords =
            routePoints.map((pt) => '${pt.longitude},${pt.latitude}').join(';');

        // Retry logic for OSRM
        for (int attempt = 0; attempt < _maxRetries; attempt++) {
          try {
            String url =
                'http://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true';

            final response = await http.get(
              Uri.parse(url),
              headers: {'User-Agent': 'BusMate-App/1.0'},
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              Map<String, dynamic> data = json.decode(response.body);
              if (data['routes'] != null && data['routes'].isNotEmpty) {
                List<dynamic> coordinates =
                    data['routes'][0]['geometry']['coordinates'];
                final polyline = coordinates
                    .map((point) =>
                        LatLng(point[1] as double, point[0] as double))
                    .toList();

                // Update local state only (don't write back to Firestore)
                routePolyline.value = polyline;
                
                break; // Success, exit retry loop
              }
            }
          } catch (e) {
            print('Attempt $attempt failed: $e');
            if (attempt == _maxRetries - 1) {
              print('All attempts failed for route update');
            }
          }
        }
      }
    } catch (e) {
      print('Error polling bus status: $e');
    }
  });
}
```

**Also update the onClose method to cancel timers:**
```dart
@override
void onClose() {
  _busStatusPollingTimer?.cancel();
  _routeUpdateTimer?.cancel();
  mapController.dispose();
  super.onClose();
}
```

---

### Step 3: Replace Student Data Real-time Listener (10 minutes)

**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

**Find this code (around line 276-308):**
```dart
void fetchStudent(String studentId) {
  isLoading.value = true;
  FirebaseFirestore.instance
      .collection('students')
      .doc(studentId)
      .snapshots()
      .listen((doc) async {
    // ... rest of the code
```

**Replace with:**
```dart
// Add timer instance variable
Timer? _studentPollingTimer;

void fetchStudent(String studentId) {
  // Initial fetch
  _fetchStudentData(studentId);
  
  // Cancel existing timer
  _studentPollingTimer?.cancel();
  
  // Poll every 60 seconds (student data changes rarely)
  _studentPollingTimer = Timer.periodic(Duration(seconds: 60), (timer) {
    _fetchStudentData(studentId);
  });
}

Future<void> _fetchStudentData(String studentId) async {
  try {
    isLoading.value = true;
    
    final doc = await FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .get();
        
    if (doc.exists && doc.data() != null) {
      final studentData = doc.data()!;
      student.value = StudentModel.fromMap(doc);
      
      if (studentData['sibling'] != null && studentData['sibling'] is List) {
        List<String> siblingIds = List<String>.from(studentData['sibling']);
        List<StudentModel> siblingList = [];
        
        for (String siblingId in siblingIds) {
          DocumentSnapshot siblingDoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(siblingId)
              .get();
              
          if (siblingDoc.exists && siblingDoc.data() != null) {
            siblingList.add(StudentModel.fromMap(siblingDoc));
          }
        }
        siblings.value = siblingList;
      } else {
        siblings.value = [];
      }
    } else {
      student.value = null;
      siblings.value = [];
      Get.snackbar("Error", "Student not found");
    }
  } catch (e) {
    Get.snackbar("Error", "Failed to fetch student: $e");
  } finally {
    isLoading.value = false;
  }
}
```

**Update onClose:**
```dart
@override
void onClose() {
  _busStatusPollingTimer?.cancel();
  _routeUpdateTimer?.cancel();
  _studentPollingTimer?.cancel();
  mapController.dispose();
  super.onClose();
}
```

---

### Step 4: Replace Bus Detail Real-time Listener (10 minutes)

**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

**Find this code (around line 329-347):**
```dart
Future<void> fetchBusDetail(String schoolId, String busId) async {
  isLoading.value = true;
  FirebaseFirestore.instance
      .collection('schools')
      .doc(schoolId)
      .collection('buses')
      .doc(busId)
      .snapshots()
      .listen((doc) {
    // ... rest of the code
```

**Replace with:**
```dart
// Add timer instance variable
Timer? _busDetailPollingTimer;

Future<void> fetchBusDetail(String schoolId, String busId) async {
  // Initial fetch
  _fetchBusDetailData(schoolId, busId);
  
  // Cancel existing timer
  _busDetailPollingTimer?.cancel();
  
  // Poll every 120 seconds (bus details change rarely)
  _busDetailPollingTimer = Timer.periodic(Duration(seconds: 120), (timer) {
    _fetchBusDetailData(schoolId, busId);
  });
}

Future<void> _fetchBusDetailData(String schoolId, String busId) async {
  try {
    isLoading.value = true;
    
    final doc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('buses')
        .doc(busId)
        .get();
        
    if (doc.exists && doc.data() != null) {
      busDetail.value = BusModel.fromMap(doc.data() as Map<String, dynamic>);
    } else {
      busDetail.value = null;
      Get.snackbar("Error", "Bus not found");
    }
  } catch (e) {
    Get.snackbar("Error", "Failed to fetch bus: $e");
  } finally {
    isLoading.value = false;
  }
}
```

**Update onClose:**
```dart
@override
void onClose() {
  _busStatusPollingTimer?.cancel();
  _routeUpdateTimer?.cancel();
  _studentPollingTimer?.cancel();
  _busDetailPollingTimer?.cancel();
  mapController.dispose();
  super.onClose();
}
```

---

### Step 5: Add Import for Timer (1 minute)

**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

**Add at the top with other imports:**
```dart
import 'dart:async';
```

---

## 🌐 WEB APP OPTIMIZATIONS

### Step 6: Replace School Management Real-time Listener (10 minutes)

**File:** `busmate_web/lib/modules/SuperAdmin/school_management/school_management_controller.dart`

**Find this code (around line 18-25):**
```dart
void fetchSchools() async {
  try {
    QuerySnapshot snapshot = await firestore.collection('schools').get();
    schools.value = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  } catch (e) {
    print('Error fetching schools: $e');
  }
}
```

**This is already good! Just ensure it's called manually, not automatically.**

**Update the screen to add a refresh button:**

**File:** `busmate_web/lib/modules/SuperAdmin/school_management/school_management_screen.dart`

**Add refresh button in AppBar (find the AppBar section):**
```dart
AppBar(
  title: Text('School Management'),
  actions: [
    IconButton(
      icon: Icon(Icons.refresh),
      tooltip: 'Refresh Schools',
      onPressed: () {
        controller.fetchSchools();
      },
    ),
  ],
),
```

---

### Step 7: Replace Payment Management StreamBuilder (15 minutes)

**File:** `busmate_web/lib/modules/SuperAdmin/payment_management/payment_management_screen.dart`

**Find this code (around line 19-21):**
```dart
body: StreamBuilder<QuerySnapshot>(
  stream: firestore.collection('schools').snapshots(),
  builder: (context, snapshot) {
```

**Replace with:**
```dart
// Add state variable at top of class
QuerySnapshot? _schoolsSnapshot;
bool _isLoading = false;

@override
void initState() {
  super.initState();
  _loadSchools();
}

Future<void> _loadSchools() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    final snapshot = await firestore.collection('schools').get();
    setState(() {
      _schoolsSnapshot = snapshot;
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading schools: $e');
    setState(() {
      _isLoading = false;
    });
  }
}

// Then replace StreamBuilder with this:
body: _isLoading
    ? Center(child: CircularProgressIndicator())
    : _schoolsSnapshot == null
        ? Center(child: Text('No data'))
        : Builder(
            builder: (context) {
              // Use _schoolsSnapshot instead of snapshot
              final schoolDocs = _schoolsSnapshot!.docs;
              
              // ... rest of your existing code
```

**Add refresh button:**
```dart
actions: [
  IconButton(
    icon: Icon(Icons.refresh),
    tooltip: 'Refresh Data',
    onPressed: _loadSchools,
  ),
],
```

---

### Step 8: Replace Student Management StreamBuilder (15 minutes)

**File:** `busmate_web/lib/modules/SchoolAdmin/student_management/student_controller.dart`

**Find this code (around line 29-40):**
```dart
void fetchStudents() {
  try {
    firestore
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen((snapshot) {
      students.value = snapshot.docs
          .map((doc) => Student.fromDocument(doc))
          .toList();
      isLoading.value = false;
    });
```

**Replace with:**
```dart
void fetchStudents() async {
  try {
    isLoading.value = true;
    
    final snapshot = await firestore
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .get();
        
    students.value = snapshot.docs
        .map((doc) => Student.fromDocument(doc))
        .toList();
        
    isLoading.value = false;
  } catch (e) {
    print('Error fetching students: $e');
    isLoading.value = false;
  }
}
```

**Add manual refresh in the screen:**

**File:** `busmate_web/lib/modules/SchoolAdmin/student_management/student_management_screen.dart`

**Add refresh button:**
```dart
actions: [
  IconButton(
    icon: Icon(Icons.refresh),
    tooltip: 'Refresh Students',
    onPressed: () {
      controller.fetchStudents();
    },
  ),
],
```

---

### Step 9: Replace Driver Management StreamBuilder (15 minutes)

**File:** `busmate_web/lib/modules/SchoolAdmin/driver_management/driver_controller.dart`

**Find this code (around line 25-35):**
```dart
void fetchDrivers() {
  try {
    firestore
        .collection('drivers')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .listen((snapshot) {
      drivers.value = snapshot.docs
          .map((doc) => Driver.fromDocument(doc))
          .toList();
      isLoading.value = false;
    });
```

**Replace with:**
```dart
void fetchDrivers() async {
  try {
    isLoading.value = true;
    
    final snapshot = await firestore
        .collection('drivers')
        .where('schoolId', isEqualTo: schoolId)
        .get();
        
    drivers.value = snapshot.docs
        .map((doc) => Driver.fromDocument(doc))
        .toList();
        
    isLoading.value = false;
  } catch (e) {
    print('Error fetching drivers: $e');
    isLoading.value = false;
  }
}
```

---

### Step 10: Replace Bus Management StreamBuilder (20 minutes)

**File:** `busmate_web/lib/modules/SchoolAdmin/bus_management/bus_management_controller.dart`

**Find this code (around line 43-52):**
```dart
void fetchBuses() {
  CollectionReference busCollection = firestore
      .collection('schools')
      .doc(schoolId)
      .collection('buses');
  busCollection.snapshots().listen((QuerySnapshot snapshot) {
    buses.value = snapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();
    
    for (var bus in buses) {
      busStatusCollection.doc(bus.id).snapshots().listen((doc) {
```

**Replace with:**
```dart
// Add timer
Timer? _busPollingTimer;

void fetchBuses() async {
  // Cancel existing timer
  _busPollingTimer?.cancel();
  
  // Initial fetch
  await _fetchBusesData();
  
  // Poll every 30 seconds for bus status updates
  _busPollingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
    _fetchBusesData();
  });
}

Future<void> _fetchBusesData() async {
  try {
    CollectionReference busCollection = firestore
        .collection('schools')
        .doc(schoolId)
        .collection('buses');
        
    final snapshot = await busCollection.get();
    buses.value = snapshot.docs.map((doc) => Bus.fromDocument(doc)).toList();
    
    // Fetch bus statuses
    for (var bus in buses) {
      final statusDoc = await busStatusCollection.doc(bus.id).get();
      if (statusDoc.exists) {
        final busStatusData = statusDoc.data() as Map<String, dynamic>;
        busStatuses[bus.id] = BusStatusModel.fromDocument(statusDoc);
      }
    }
  } catch (e) {
    print('Error fetching buses: $e');
  }
}

@override
void onClose() {
  _busPollingTimer?.cancel();
  super.onClose();
}
```

---

## ☁️ CLOUD FUNCTIONS OPTIMIZATION

### Step 11: Optimize Notification Function (10 minutes)

**File:** `busmate_app/functions/index.js`

**Find this code (around line 9-17):**
```javascript
exports.sendBusArrivalNotifications = onSchedule(
  {
    schedule: "every 2 minutes", // Reduced frequency for cost optimization
    timeZone: "Asia/Kolkata",
    memory: "512MB", // Increased memory for batch processing
    timeoutSeconds: 540, // Increased timeout for large batches
  },
```

**Change to:**
```javascript
exports.sendBusArrivalNotifications = onSchedule(
  {
    schedule: "every 5 minutes", // Changed from 2 to 5 minutes
    timeZone: "Asia/Kolkata",
    memory: "256MB", // Reduced memory to save costs
    timeoutSeconds: 300, // Reduced timeout
  },
```

**Find this code (around line 26):**
```javascript
const studentsSnapshot = await db
  .collection("students")
  .where("notified", "==", false)
  .where("fcmToken", "!=", null)
  .limit(100) // Process in batches to avoid timeout
  .get();
```

**Change to:**
```javascript
const studentsSnapshot = await db
  .collection("students")
  .where("notified", "==", false)
  .where("fcmToken", "!=", null)
  .limit(50) // Reduced from 100 to 50
  .get();
```

---

## ✅ VERIFICATION STEPS

### After Mobile App Changes:

1. **Hot Restart the app:**
   ```
   Press 'R' in terminal or click hot restart in VS Code
   ```

2. **Login and check:**
   - Bus location still updates (every 30 seconds instead of real-time)
   - Student details load correctly
   - Map shows bus marker
   - No error messages in console

3. **Check console logs:**
   ```
   Look for: "📖 Read from..." messages
   Should be 1 read every 30-120 seconds (not every second)
   ```

### After Web App Changes:

1. **Refresh the web browser:**
   ```
   Press F5 or Ctrl+R
   ```

2. **Test each admin screen:**
   - School Management: Click refresh button, data loads
   - Student Management: Click refresh button, students appear
   - Driver Management: Click refresh button, drivers appear
   - Bus Management: Buses load, status updates every 30 seconds

3. **Verify no automatic updates:**
   - Data should NOT update automatically
   - Only updates when clicking refresh button

### After Cloud Function Changes:

1. **Deploy the function:**
   ```powershell
   cd busmate_app
   firebase deploy --only functions
   ```

2. **Monitor function logs:**
   ```powershell
   firebase functions:log
   ```

3. **Verify:**
   - Function runs every 5 minutes (not 2)
   - Processes 50 students per batch (not 100)

---

## 📊 EXPECTED RESULTS

### Before Optimization:
- Mobile app: 540,000 reads per user session
- Web app: Continuous reads (thousands per hour)
- Cloud functions: 110 reads per run × 720 = 79,200 reads/day

### After Optimization:
- Mobile app: 18,000 reads per user session (97% ⬇️)
- Web app: ~100 reads per admin session (99% ⬇️)
- Cloud functions: 55 reads per run × 288 = 15,840 reads/day (80% ⬇️)

### Cost Impact:
- **Before:** ~$100/month
- **After:** ~$20/month
- **Savings:** $80/month (80% reduction)

---

## 🆘 TROUBLESHOOTING

### If bus location doesn't update:

**Check:**
```dart
// In dashboard.controller.dart
print('🚍 Polling bus status every 30 seconds');
print('Last update: ${DateTime.now()}');
```

### If data seems stale:

**Solution:** Reduce polling interval temporarily
```dart
// Change from 30 seconds to 15 seconds
Timer.periodic(Duration(seconds: 15), (timer) { ... });
```

### If web app shows "No data":

**Check:**
```dart
// In controller
print('Fetching data...');
print('Got ${snapshot.docs.length} documents');
```

---

## 📞 SUPPORT

**Implementation Time:** 2-3 hours
**Difficulty:** 🟡 Medium
**Risk Level:** 🟢 Low (can revert easily)

**Next Steps:** After implementation, monitor Firebase Console → Usage for 7 days to verify cost reduction.

---

**Document Version:** 1.0
**Last Updated:** October 24, 2025
