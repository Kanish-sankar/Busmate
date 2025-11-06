# 🔥 Firebase Structure Analysis & Cost Optimization Guide

## 📊 Current Firebase Architecture

### **Project:** `busmate-b80e8`

---

## 1️⃣ FIRESTORE DATABASE STRUCTURE

### **Root Collections:**

```
firebase/
├── students/                    # Student records
│   └── {studentId}/
│       ├── id: string
│       ├── assignedBusId: string
│       ├── assignedDriverId: string
│       ├── email: string
│       ├── languagePreference: string
│       ├── name: string
│       ├── notificationPreferenceByLocation: string
│       ├── notificationPreferenceByTime: number
│       ├── fcmToken: string
│       ├── notificationType: string
│       ├── parentContact: string
│       ├── password: string (⚠️ SECURITY RISK)
│       ├── rollNumber: string
│       ├── schoolId: string
│       ├── stopping: string
│       ├── studentClass: string
│       └── siblings: string[]
│
├── drivers/                     # Driver records
│   └── {driverId}/
│       ├── id: string
│       ├── assignedBusId: string
│       ├── available: boolean
│       ├── contactInfo: string
│       ├── email: string
│       ├── licenseNumber: string
│       ├── name: string
│       ├── password: string (⚠️ SECURITY RISK)
│       ├── profileImageUrl: string
│       └── schoolId: string
│
├── schools/                     # School records
│   └── {schoolId}/
│       ├── address: string
│       ├── created_at: timestamp
│       ├── email: string
│       ├── package_type: string
│       ├── password: string (⚠️ SECURITY RISK)
│       ├── phone_number: string
│       ├── school_id: string
│       ├── school_name: string
│       ├── uid: string
│       ├── updated_at: timestamp
│       │
│       ├── buses/              # Subcollection (nested)
│       │   └── {busId}/
│       │       ├── busNo: string
│       │       ├── driverId: string
│       │       ├── driverName: string
│       │       ├── gpsType: string
│       │       ├── routeName: string
│       │       ├── busVehicleNo: string
│       │       ├── stoppings: array<object>
│       │       │   └── { name, latitude, longitude, order }
│       │       ├── students: string[]
│       │       ├── currentLocation: { latitude, longitude }
│       │       ├── currentSpeed: number
│       │       ├── currentStatus: string
│       │       └── remainingStops: array<object>
│       │
│       └── payments/           # Subcollection (nested)
│           └── {paymentId}/
│               ├── amount: number
│               ├── status: string
│               ├── paymentDate: timestamp
│               └── studentId: string
│
├── bus_status/                  # Real-time bus tracking
│   └── {busId}/
│       ├── busId: string
│       ├── schoolId: string
│       ├── currentLocation: { latitude, longitude }
│       ├── latitude: number
│       ├── longitude: number
│       ├── currentSpeed: number
│       ├── currentStatus: string ('Active', 'InActive')
│       ├── remainingStops: array<object>
│       ├── lastUpdated: timestamp
│       ├── isDelayed: boolean
│       ├── lastMovedTime: timestamp
│       ├── currentSegment: string
│       ├── busRouteType: string ('pickup', 'drop')
│       ├── routePolyline: array<{latitude, longitude}>
│       └── recentSpeeds: array<{time, speed}>
│
├── notifications/               # Notification history
│   └── {notificationId}/
│       ├── id: string
│       ├── title: string
│       ├── message: string
│       ├── sentAt: timestamp
│       ├── recipientGroups: string[]
│       ├── schoolIds: string[]
│       ├── senderId: string
│       ├── extraData: object
│       └── status: string
│
├── notificationTimers/          # Scheduled notifications
│   └── {timerId}/
│       ├── scheduledAt: timestamp
│       ├── studentId: string
│       ├── busId: string
│       └── notified: boolean
│
└── payment/                     # Global payment records
    └── {paymentId}/
        ├── schoolId: string
        ├── studentId: string
        ├── amount: number
        ├── status: string ('pending', 'completed', 'failed')
        ├── paymentDate: timestamp
        └── paymentMethod: string
```

---

## 2️⃣ FIREBASE AUTHENTICATION

### **Current Setup:**
- **Provider:** Email/Password
- **User Types:** 
  - Students (stored in `students` collection)
  - Drivers (stored in `drivers` collection)
  - School Admins (stored in `schools` collection)

### **⚠️ SECURITY ISSUES:**
1. **Plaintext Passwords in Firestore** - Passwords stored directly in documents
2. **No Role-Based Access Control (RBAC)** - Custom claims not implemented
3. **Permissive Rules** - Current rules allow broad access

---

## 3️⃣ FIREBASE CLOUD FUNCTIONS

### **BusMate App Functions** (`busmate_app/functions/index.js`)

#### **Function 1: `sendBusArrivalNotifications`**
- **Trigger:** Scheduled (every 2 minutes)
- **Purpose:** Send push notifications when bus is near student's stop
- **Cost Impact:** 🔴 **HIGH**
  - Runs 720 times/day (every 2 minutes)
  - Queries `students` collection (100 docs per run = 72,000 reads/day)
  - Queries `bus_status` collection per bus
  - **Estimated:** 100,000+ reads/day

**Process Flow:**
```javascript
1. Query students.where('notified', '==', false).limit(100)
2. Group students by busId
3. For each busId, query bus_status collection
4. Calculate ETA for each student
5. Send FCM notifications
6. Update student.notified = true
```

**Cost Contributors:**
- 72,000 student reads/day
- ~5,000 bus_status reads/day
- 10,000+ FCM messages/day (free tier: 10k/month)

### **BusMate Web Functions** (`busmate_web/functions/src/index.ts`)

#### **Function 2: `autocomplete`**
- **Trigger:** HTTPS request
- **Purpose:** Proxy Google Places API autocomplete
- **Cost Impact:** 🟡 **MEDIUM**
  - Depends on usage frequency
  - Google Maps API charges apply

#### **Function 3: `geocode`**
- **Trigger:** HTTPS request
- **Purpose:** Convert place_id to coordinates
- **Cost Impact:** 🟡 **MEDIUM**

---

## 4️⃣ FIREBASE CLOUD STORAGE

### **Current Usage:**
- **Location:** `busmate-b80e8.firebasestorage.app`
- **Files Stored:**
  - Driver profile images (`driver_images/{driverId}`)
  - Bus images (minimal)
- **Cost Impact:** 🟢 **LOW** (minimal storage usage)

---

## 5️⃣ FIREBASE CLOUD MESSAGING (FCM)

### **Current Usage:**
- Student notifications (bus arrival alerts)
- Voice notifications with language-specific sounds
- **Free Tier:** 10,000 messages/month
- **⚠️ Potential Overage:** 72,000 reads/day = 30k+ messages/month

---

## 6️⃣ REAL-TIME LISTENERS (COST ANALYSIS)

### **Mobile App (busmate_app) - Real-time Subscriptions:**

| Screen/Controller | Collection | Listener Type | Frequency | Cost Impact |
|------------------|-----------|---------------|-----------|-------------|
| **DashboardController** | `students/{studentId}` | snapshots() | Continuous | 🔴 HIGH (1 read/sec) |
| **DashboardController** | `schools/{schoolId}/buses/{busId}` | snapshots() | Continuous | 🔴 HIGH |
| **DashboardController** | `bus_status/{busId}` | snapshots() | Continuous | 🔴 VERY HIGH |
| **DashboardController** | `bus_status/{busId}` (polyline) | snapshots() | Every 10 sec | 🔴 HIGH |
| **StopLocationController** | `schools/{schoolId}/buses/{busId}` | snapshots() | Continuous | 🔴 HIGH |
| **StopNotifyController** | `bus_status/{busId}` | snapshots() | Continuous | 🔴 HIGH |
| **DriverController** | `drivers/{driverId}` | snapshots() | Continuous | 🟡 MEDIUM |

**Estimated Real-time Reads:**
- **Per user session (30 min):** 1,800 reads (1 read/sec)
- **100 active users:** 180,000 reads/day
- **Monthly:** 5.4 million reads

### **Web App (busmate_web) - Real-time Subscriptions:**

| Screen/Controller | Collection | Listener Type | Frequency | Cost Impact |
|------------------|-----------|---------------|-----------|-------------|
| **SuperAdmin Dashboard** | `schools` | snapshots() | Continuous | 🔴 HIGH |
| **Payment Management** | `schools/{schoolId}/payments` | snapshots() | Continuous | 🔴 HIGH |
| **Student Management** | `students` (filtered) | snapshots() | Continuous | 🔴 HIGH |
| **Driver Management** | `drivers` (filtered) | snapshots() | Continuous | 🟡 MEDIUM |
| **Bus Management** | `schools/{schoolId}/buses` | snapshots() | Continuous | 🔴 HIGH |
| **Bus Management** | `bus_status/{busId}` | snapshots() | Continuous | 🔴 VERY HIGH |
| **Notifications** | `notifications` | snapshots() | Continuous | 🟡 MEDIUM |
| **Admin Management** | `school_admins` | snapshots() | Continuous | 🟡 MEDIUM |

**Estimated Real-time Reads:**
- **Per admin session (4 hours):** 14,400 reads
- **10 active admins:** 144,000 reads/day
- **Monthly:** 4.3 million reads

---

## 7️⃣ TOTAL COST BREAKDOWN (ESTIMATED)

### **Firestore Reads:**
```
Mobile App Real-time Listeners:    5,400,000 reads/month
Web App Real-time Listeners:       4,300,000 reads/month
Cloud Function Queries:            3,000,000 reads/month
Login/Manual Queries:                500,000 reads/month
────────────────────────────────────────────────────────
TOTAL:                            13,200,000 reads/month
```

**Firebase Free Tier:** 50,000 reads/day (1.5M/month)
**Overage:** 11.7M reads × $0.06 per 100k = **$70.20/month**

### **Firestore Writes:**
```
Bus location updates:              2,000,000 writes/month
Notification updates:                200,000 writes/month
Student/Driver updates:               50,000 writes/month
────────────────────────────────────────────────────────
TOTAL:                             2,250,000 writes/month
```

**Free Tier:** 20,000 writes/day (600k/month)
**Overage:** 1.65M writes × $0.18 per 100k = **$29.70/month**

### **Cloud Functions:**
```
Notification function (every 2 min): 720 invocations/day
Autocomplete/Geocode:                ~500 invocations/day
────────────────────────────────────────────────────────
TOTAL:                               ~1,220 invocations/day
```

**Free Tier:** 2M invocations/month
**Within Free Tier:** ✅

### **Cloud Messaging:**
```
Push notifications:                  ~30,000 messages/month
```

**Free Tier:** 10,000 messages/month
**Overage:** 20k messages × $0.01 per 1k = **$0.20/month**

### **💰 TOTAL ESTIMATED MONTHLY COST: ~$100**

---

## 8️⃣ OPTIMIZATION STRATEGIES

### **🎯 Priority 1: REDUCE REAL-TIME LISTENERS (Save $50/month)**

#### **Mobile App Optimizations:**

1. **Replace Continuous Listeners with Polling:**
```dart
// ❌ BEFORE (Continuous listener)
FirebaseFirestore.instance
  .collection('bus_status')
  .doc(busId)
  .snapshots()  // 1 read per second
  .listen((doc) { ... });

// ✅ AFTER (Polling every 30 seconds)
Timer.periodic(Duration(seconds: 30), (timer) async {
  final doc = await FirebaseFirestore.instance
    .collection('bus_status')
    .doc(busId)
    .get();  // 1 read per 30 seconds
  // Process data
});
```

**Savings:** 97% reduction (1 read/sec → 1 read/30sec)

2. **Use Conditional Listeners (Only When Bus Active):**
```dart
// Only listen when bus status is 'Active'
if (busStatus.currentStatus == 'Active') {
  // Start real-time listener
} else {
  // Use polling or stop listening
}
```

3. **Implement Local Caching:**
```dart
// Use CacheManager (already partially implemented)
final cachedData = await CacheManager.getCached<Map>('bus_status_$busId');
if (cachedData != null && !_isStale(cachedData)) {
  return cachedData;
}
// Otherwise fetch from Firestore
```

4. **Debounce Map Updates:**
```dart
// Already implemented: mapUpdateThreshold = 100ms
// Consider increasing to 500ms for less frequent updates
static const mapUpdateThreshold = Duration(milliseconds: 500);
```

#### **Web App Optimizations:**

1. **Paginate Collections:**
```dart
// Use existing DatabaseQueryHelper methods
final result = await DatabaseQueryHelper.getStudentsPaginated(
  schoolId: schoolId,
  pageSize: 20,  // Load 20 at a time instead of all
);
```

2. **Replace StreamBuilder with Manual Refresh:**
```dart
// ❌ BEFORE
StreamBuilder<QuerySnapshot>(
  stream: firestore.collection('schools').snapshots(),
  builder: (context, snapshot) { ... }
);

// ✅ AFTER
FutureBuilder<QuerySnapshot>(
  future: firestore.collection('schools').get(),
  builder: (context, snapshot) { 
    // Add manual refresh button
  }
);
```

3. **Implement Data Refresh on User Action:**
```dart
// Only fetch when user clicks "Refresh" button
onPressed: () async {
  await controller.fetchSchools();  // Manual fetch
}
```

---

### **🎯 Priority 2: OPTIMIZE CLOUD FUNCTIONS (Save $20/month)**

#### **Notification Function Optimization:**

1. **Increase Schedule Interval:**
```javascript
// ❌ BEFORE: every 2 minutes = 720 runs/day
exports.sendBusArrivalNotifications = onSchedule({
  schedule: "every 2 minutes",
  ...
});

// ✅ AFTER: every 5 minutes = 288 runs/day (60% reduction)
exports.sendBusArrivalNotifications = onSchedule({
  schedule: "every 5 minutes",
  ...
});
```

**Savings:** 432 fewer runs/day = 48,000 fewer reads/day

2. **Add Smart Filtering:**
```javascript
// Only query students with buses currently active
const activeStudentsSnapshot = await db
  .collection("students")
  .where("notified", "==", false)
  .where("busActive", "==", true)  // Add this field
  .limit(50)  // Reduce batch size
  .get();
```

3. **Cache Bus Status:**
```javascript
// Cache bus_status in memory for 2 minutes
const busCache = new Map();
const CACHE_TTL = 2 * 60 * 1000;

function getCachedBusStatus(busId) {
  const cached = busCache.get(busId);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  return null;
}
```

4. **Use Batch Queries:**
```javascript
// Fetch all bus statuses in one query instead of per-bus
const busStatusesSnapshot = await db
  .collection("bus_status")
  .where("isActive", "==", true)
  .get();

// Create a map for quick lookup
const busStatusMap = new Map(
  busStatusesSnapshot.docs.map(doc => [doc.id, doc.data()])
);
```

---

### **🎯 Priority 3: DATABASE SCHEMA OPTIMIZATION (Save $15/month)**

#### **1. Remove Duplicate Data:**

**Problem:** Student data duplicated in multiple places
```
students/{studentId}  → Full student object
schools/{schoolId}/buses/{busId}.students[]  → Student IDs
```

**Solution:** Use only references, fetch when needed
```dart
// Store only IDs in bus document
bus.students = ['studentId1', 'studentId2'];

// Fetch student details only when displaying
final students = await DatabaseQueryHelper.getStudentsPaginated(
  schoolId: schoolId,
  busId: busId,
  pageSize: 20,
);
```

#### **2. Separate Static and Dynamic Data:**

**Problem:** `bus_status` includes both static (route) and dynamic (location) data

**Solution:** Split collections
```
buses/{busId}/              → Static data (route, stops, students)
bus_tracking/{busId}/       → Dynamic data (location, speed)
  ├── current_location
  ├── current_speed
  └── last_updated
```

**Benefit:** Update only `bus_tracking` frequently (smaller documents, faster writes)

#### **3. Implement Composite Indexes:**

Create indexes for common queries:
```javascript
// Firestore indexes (firestore.indexes.json)
{
  "indexes": [
    {
      "collectionGroup": "students",
      "fields": [
        { "fieldPath": "schoolId", "order": "ASCENDING" },
        { "fieldPath": "assignedBusId", "order": "ASCENDING" },
        { "fieldPath": "notified", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "bus_status",
      "fields": [
        { "fieldPath": "schoolId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" }
      ]
    }
  ]
}
```

#### **4. Archive Old Data:**

**Problem:** Notifications and payment records accumulate forever

**Solution:** Implement automatic cleanup
```dart
// Already partially implemented in database_query_helper.dart
static Future<void> cleanupOldData() async {
  DateTime cutoffDate = DateTime.now().subtract(Duration(days: 90));
  
  // Delete notifications older than 90 days
  QuerySnapshot oldNotifications = await _firestore
    .collection('notifications')
    .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
    .limit(100)
    .get();
  
  // Batch delete
  WriteBatch batch = _firestore.batch();
  for (DocumentSnapshot doc in oldNotifications.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}
```

**Schedule cleanup:** Run monthly via Cloud Function

---

### **🎯 Priority 4: SECURITY IMPROVEMENTS (CRITICAL)**

#### **1. Remove Plaintext Passwords:**

**⚠️ CRITICAL SECURITY ISSUE:** Passwords stored in Firestore

**Solution:** Use Firebase Authentication only
```dart
// ❌ REMOVE from Firestore documents
students/{studentId}.password  // DELETE THIS FIELD
drivers/{driverId}.password    // DELETE THIS FIELD
schools/{schoolId}.password    // DELETE THIS FIELD

// ✅ Use Firebase Auth
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,  // Only stored in Firebase Auth (encrypted)
);
```

#### **2. Implement Firestore Security Rules:**

**Current Rules:** Too permissive (development mode)

**Recommended Production Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function hasRole(role) {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role;
    }
    
    // Students collection
    match /students/{studentId} {
      allow read: if isOwner(studentId) || hasRole('admin') || hasRole('driver');
      allow write: if hasRole('admin');
      allow create: if hasRole('admin');
      allow delete: if hasRole('admin');
    }
    
    // Drivers collection
    match /drivers/{driverId} {
      allow read: if isOwner(driverId) || hasRole('admin');
      allow write: if isOwner(driverId) || hasRole('admin');
      allow create: if hasRole('admin');
      allow delete: if hasRole('admin');
    }
    
    // Bus status (read-only for students)
    match /bus_status/{busId} {
      allow read: if isAuthenticated();
      allow write: if hasRole('driver') || hasRole('admin');
    }
    
    // Schools collection
    match /schools/{schoolId} {
      allow read: if isAuthenticated();
      allow write: if hasRole('superadmin');
      
      // Buses subcollection
      match /buses/{busId} {
        allow read: if isAuthenticated();
        allow write: if hasRole('admin') || hasRole('superadmin');
      }
      
      // Payments subcollection
      match /payments/{paymentId} {
        allow read: if hasRole('admin') || hasRole('superadmin');
        allow write: if hasRole('admin') || hasRole('superadmin');
      }
    }
    
    // Notifications
    match /notifications/{notificationId} {
      allow read: if isAuthenticated();
      allow write: if hasRole('admin') || hasRole('superadmin');
    }
    
    // Payment collection
    match /payment/{paymentId} {
      allow read: if isAuthenticated();
      allow write: if hasRole('admin') || hasRole('superadmin');
    }
  }
}
```

#### **3. Add Custom Claims for Role-Based Access:**

```dart
// In Cloud Function (admin SDK)
admin.auth().setCustomUserClaims(uid, {
  role: 'student',  // or 'driver', 'admin', 'superadmin'
  schoolId: 'school123',
});

// In Flutter app
final idTokenResult = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
final role = idTokenResult?.claims?['role'];
```

---

### **🎯 Priority 5: IMPLEMENT CACHING STRATEGY (Save $10/month)**

#### **1. Enable Offline Persistence:**

```dart
// In main.dart
await FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 100 * 1024 * 1024,  // 100MB cache
);
```

**Benefit:** Automatic caching of documents, reduces reads on app restart

#### **2. Use CacheManager for API Data:**

```dart
// Already implemented in database_query_helper.dart
// Use it consistently across all controllers

// Example usage:
final cachedStudents = await CacheManager.getCached<List>('students_$schoolId');
if (cachedStudents != null) {
  return cachedStudents;
}

// Fetch from Firestore
final students = await fetchStudentsFromFirestore();
await CacheManager.setCached('students_$schoolId', students, ttl: Duration(minutes: 10));
```

#### **3. Implement Smart Cache Invalidation:**

```dart
// Clear cache when data changes
await FirebaseFirestore.instance
  .collection('students')
  .doc(studentId)
  .update(data);

// Invalidate related cache
await CacheManager.clearByPattern('students_');
```

---

## 9️⃣ RECOMMENDED IMPLEMENTATION PLAN

### **Phase 1: Quick Wins (Week 1) - Save $40/month**

1. ✅ **Already Done:** Remove automatic fetching of all students/drivers
2. 🔲 Replace continuous listeners with polling (30-second intervals)
3. 🔲 Increase Cloud Function schedule from 2 min → 5 min
4. 🔲 Enable Firestore offline persistence
5. 🔲 Add cache to frequently accessed data

**Expected Savings:** $40/month

### **Phase 2: Structural Changes (Week 2-3) - Save $30/month**

1. 🔲 Implement pagination for web admin panels
2. 🔲 Split bus static/dynamic data into separate collections
3. 🔲 Add conditional listeners (only when bus active)
4. 🔲 Implement data archival/cleanup function
5. 🔲 Optimize Cloud Function batch queries

**Expected Savings:** $30/month

### **Phase 3: Security Hardening (Week 4) - CRITICAL**

1. 🔲 Remove all password fields from Firestore
2. 🔲 Implement proper security rules
3. 🔲 Add custom claims for role-based access
4. 🔲 Audit and test all security rules

**Expected Savings:** $0 (but critical for security)

### **Phase 4: Advanced Optimization (Ongoing) - Save $20/month**

1. 🔲 Implement Redis/Memcached for hot data
2. 🔲 Use Cloud Run for scheduled tasks (instead of Functions)
3. 🔲 Compress large documents (polyline data)
4. 🔲 Implement request batching

**Expected Savings:** $20/month

---

## 🔟 MONITORING & METRICS

### **Set Up Firebase Usage Alerts:**

1. Go to Firebase Console → Usage and Billing
2. Set budget alerts:
   - Warning at $50/month
   - Alert at $75/month
   - Hard limit at $100/month

### **Track Key Metrics:**

```dart
// Add logging to track read/write operations
class FirebaseMetrics {
  static int totalReads = 0;
  static int totalWrites = 0;
  
  static void logRead(String collection) {
    totalReads++;
    print('📖 Read from $collection (Total: $totalReads)');
  }
  
  static void logWrite(String collection) {
    totalWrites++;
    print('✏️ Write to $collection (Total: $totalWrites)');
  }
}
```

### **Review Monthly:**
- Firestore read/write counts
- Cloud Function invocation counts
- Storage usage
- FCM message counts

---

## 📌 SUMMARY: COST REDUCTION ROADMAP

| Phase | Actions | Time | Savings | Difficulty |
|-------|---------|------|---------|------------|
| **Phase 1** | Replace real-time listeners, enable caching | 1 week | $40/mo | 🟢 Easy |
| **Phase 2** | Pagination, data split, cleanup | 2-3 weeks | $30/mo | 🟡 Medium |
| **Phase 3** | Security hardening | 1 week | $0 | 🟡 Medium |
| **Phase 4** | Advanced optimization | Ongoing | $20/mo | 🔴 Hard |
| **TOTAL** | All phases | 6-8 weeks | **$90/mo** | - |

**Current Cost:** ~$100/month
**Optimized Cost:** ~$10/month (within free tier)
**Annual Savings:** ~$1,080

---

## 🚨 IMMEDIATE ACTION ITEMS (THIS WEEK)

### **Mobile App (`busmate_app`):**

1. **Replace bus_status snapshot listener with polling:**
   - File: `dashboard.controller.dart`
   - Change `snapshots().listen()` to `Timer.periodic(30 sec)`

2. **Add conditional listening:**
   - Only listen to bus location when `currentStatus == 'Active'`

3. **Enable offline persistence:**
   - File: `main.dart`
   - Add `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)`

### **Web App (`busmate_web`):**

1. **Replace StreamBuilder with FutureBuilder:**
   - Files: All management screens
   - Add manual refresh buttons

2. **Implement pagination:**
   - Use existing `DatabaseQueryHelper.getStudentsPaginated()`
   - Load 20 records at a time

3. **Remove continuous school listener:**
   - File: `dashboard_controller.dart`
   - Use manual refresh instead

### **Cloud Functions:**

1. **Increase notification schedule:**
   - File: `functions/index.js`
   - Change from `every 2 minutes` to `every 5 minutes`

2. **Add bus status caching:**
   - Implement in-memory cache with 2-minute TTL

3. **Reduce student query limit:**
   - Change from `limit(100)` to `limit(50)`

---

## 📚 ADDITIONAL RESOURCES

- **Firebase Pricing Calculator:** https://firebase.google.com/pricing
- **Firestore Best Practices:** https://firebase.google.com/docs/firestore/best-practices
- **Security Rules Reference:** https://firebase.google.com/docs/firestore/security/get-started
- **Cloud Functions Optimization:** https://cloud.google.com/functions/docs/bestpractices/tips

---

**Document Version:** 1.0
**Last Updated:** October 24, 2025
**Project:** BusMate (busmate-b80e8)
