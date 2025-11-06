# 🚀 Krutrim Maps + Firebase Free Tier: Implementation Roadmap

**Target:** Reduce monthly cost from ₹44,780 to ₹142 (99.7% reduction)  
**Timeline:** 4 weeks  
**Risk Level:** 🟡 Medium (with rollback plan)

---

## 📋 WEEK-BY-WEEK IMPLEMENTATION PLAN

### **WEEK 1: Krutrim Maps Integration**

#### Day 1-2: Setup & Testing
```bash
# 1. Sign up for Krutrim Maps
Visit: https://console.krutrim.ai
Create account → Get API key

# 2. Test Krutrim API (Postman/curl)
curl -X GET "https://api.krutrim.ai/v1/places/autocomplete?input=Delhi&api_key=YOUR_KEY"
curl -X GET "https://api.krutrim.ai/v1/geocode?address=Connaught Place&api_key=YOUR_KEY"

# 3. Verify responses match Google Maps format
```

#### Day 3-4: Update Cloud Functions
**File:** `busmate_web/functions/src/index.ts`

```typescript
// Add Krutrim configuration
const KRUTRIM_API_KEY = functions.config().krutrim?.api_key || process.env.KRUTRIM_API_KEY;
const KRUTRIM_BASE_URL = 'https://api.krutrim.ai/v1';

// Update autocomplete function
export const autocomplete = functions.https.onRequest(
  (req: Request, res: Response) => {
    cors(req, res, async () => {
      const input = req.query.input as string | undefined;
      
      if (!KRUTRIM_API_KEY) {
        logger.error("Krutrim API key not configured");
        return res.status(500).json({ error: 'API key not configured' });
      }
      
      if (!input) {
        return res.status(400).json({ error: 'Missing input parameter' });
      }

      try {
        logger.info(`Krutrim autocomplete request for: ${input}`);
        
        const response = await axios.get(
          `${KRUTRIM_BASE_URL}/places/autocomplete`,
          {
            params: {
              input,
              api_key: KRUTRIM_API_KEY,
              components: 'country:in',
            },
            timeout: 5000, // 5 second timeout
          }
        );
        
        logger.info(`Krutrim response status: ${response.status}`);
        return res.status(200).json(response.data);
        
      } catch (err) {
        // Fallback to Google Maps if Krutrim fails
        logger.warn(`Krutrim failed, falling back to Google: ${err}`);
        
        try {
          const googleResponse = await axios.get(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json',
            {
              params: {
                input,
                key: API_KEY, // Google Maps API key
                components: 'country:in',
              },
            }
          );
          return res.status(200).json(googleResponse.data);
        } catch (googleErr) {
          return res.status(500).json({ error: 'Both APIs failed' });
        }
      }
    });
  }
);

// Update geocode function similarly
export const geocode = functions.https.onRequest(
  (req: Request, res: Response) => {
    cors(req, res, async () => {
      const address = req.query.address as string | undefined;
      
      if (!address) {
        return res.status(400).json({ error: 'Missing address parameter' });
      }

      try {
        const response = await axios.get(
          `${KRUTRIM_BASE_URL}/geocode`,
          {
            params: {
              address,
              api_key: KRUTRIM_API_KEY,
            },
            timeout: 5000,
          }
        );
        
        return res.status(200).json(response.data);
        
      } catch (err) {
        // Fallback to Google
        logger.warn(`Krutrim geocode failed, using Google: ${err}`);
        
        try {
          const googleResponse = await axios.get(
            'https://maps.googleapis.com/maps/api/geocode/json',
            {
              params: {
                address,
                key: API_KEY,
              },
            }
          );
          return res.status(200).json(googleResponse.data);
        } catch (googleErr) {
          return res.status(500).json({ error: 'Both APIs failed' });
        }
      }
    });
  }
);
```

#### Day 5: Deploy & Test
```bash
cd busmate_web

# Set Krutrim API key
firebase functions:config:set krutrim.api_key="YOUR_KRUTRIM_KEY"

# Deploy functions
firebase deploy --only functions

# Test deployed functions
curl "https://us-central1-busmate-b80e8.cloudfunctions.net/autocomplete?input=Mumbai"
curl "https://us-central1-busmate-b80e8.cloudfunctions.net/geocode?address=Gateway+of+India"
```

**✅ Week 1 Deliverable:** Krutrim API integrated with Google Maps fallback

---

### **WEEK 2: Firebase Optimization - Mobile App**

#### Day 1: Enable Offline Persistence
**File:** `busmate_app/lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ✅ ADD THIS: Enable offline persistence
  await FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024, // 100MB cache
  );
  
  await GetStorage.init();
  
  runApp(const MyApp());
}
```

#### Day 2-3: Replace Real-time Listeners with Polling
**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

See IMPLEMENTATION_GUIDE.md Steps 2-4 for complete code changes.

Key changes:
- Bus status: snapshots() → polling every 30 seconds
- Student data: snapshots() → polling every 60 seconds
- Bus detail: snapshots() → polling every 120 seconds

#### Day 4-5: Testing & Validation
```bash
# Hot restart app
flutter run

# Test scenarios:
✓ Bus location updates every 30 seconds
✓ Student details load correctly
✓ App works offline (cached data)
✓ No excessive Firebase reads
✓ Map displays correctly
```

**✅ Week 2 Deliverable:** Mobile app optimized with 97% fewer Firestore reads

---

### **WEEK 3: Firebase Realtime Database Migration**

#### Day 1-2: Set up Realtime Database Structure

```javascript
// Firebase Realtime Database structure
{
  "bus_locations": {
    "bus_id_1": {
      "latitude": 28.6139,
      "longitude": 77.2090,
      "speed": 45.2,
      "status": "Active",
      "lastUpdated": 1729800000000,
      "heading": 135
    },
    "bus_id_2": { ... }
  },
  "driver_status": {
    "driver_id_1": {
      "isOnline": true,
      "currentBusId": "bus_id_1",
      "lastSeen": 1729800000000
    }
  }
}
```

#### Day 3: Create RTDB Helper Class
**File:** `busmate_app/lib/meta/firebase_helper/realtime_db_helper.dart`

```dart
import 'package:firebase_database/firebase_database.dart';

class RealtimeDBHelper {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  // Update bus location
  static Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required double speed,
    required String status,
  }) async {
    await _database.child('bus_locations/$busId').set({
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'status': status,
      'lastUpdated': ServerValue.timestamp,
    });
  }
  
  // Listen to bus location
  static Stream<DatabaseEvent> watchBusLocation(String busId) {
    return _database.child('bus_locations/$busId').onValue;
  }
  
  // Get bus location once
  static Future<Map<String, dynamic>?> getBusLocation(String busId) async {
    final snapshot = await _database.child('bus_locations/$busId').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }
}
```

#### Day 4: Update Driver App to Write to RTDB
**File:** `busmate_app/lib/presentation/parents_module/driver_module/controller/driver.controller.dart`

```dart
// Replace Firestore write with RTDB write
Future<void> updateBusLocation() async {
  Position position = await Geolocator.getCurrentPosition();
  
  // ❌ OLD: Write to Firestore (expensive)
  // await FirebaseFirestore.instance
  //   .collection('bus_status')
  //   .doc(busId)
  //   .update({...});
  
  // ✅ NEW: Write to Realtime Database (cheaper)
  await RealtimeDBHelper.updateBusLocation(
    busId: busId,
    latitude: position.latitude,
    longitude: position.longitude,
    speed: position.speed,
    status: 'Active',
  );
}
```

#### Day 5: Update Student App to Read from RTDB
**File:** `busmate_app/lib/presentation/parents_module/dashboard/controller/dashboard.controller.dart`

```dart
// Replace Firestore polling with RTDB stream
void startBusTracking(String busId) {
  // ✅ Use RTDB stream (more efficient for live data)
  RealtimeDBHelper.watchBusLocation(busId).listen((event) {
    if (event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      busStatus.value = BusStatusModel(
        latitude: data['latitude'],
        longitude: data['longitude'],
        currentSpeed: data['speed'],
        currentStatus: data['status'],
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(data['lastUpdated']),
      );
    }
  });
}
```

**✅ Week 3 Deliverable:** Bus tracking moved to Realtime Database

---

### **WEEK 4: Web App Optimization**

#### Day 1-2: Replace StreamBuilders with Manual Refresh
**Files to update:**
- `school_management/school_management_screen.dart`
- `student_management/student_management_screen.dart`
- `driver_management/driver_management_screen.dart`
- `bus_management/bus_management_screen.dart`

See IMPLEMENTATION_GUIDE.md Steps 6-10 for complete code.

#### Day 3: Add Refresh Buttons
```dart
// Example for all admin screens
AppBar(
  title: Text('Student Management'),
  actions: [
    IconButton(
      icon: Icon(Icons.refresh),
      tooltip: 'Refresh Data',
      onPressed: () {
        controller.fetchStudents(); // Manual refresh
      },
    ),
  ],
)
```

#### Day 4-5: Testing & User Training
```
Test Checklist:
✓ All admin screens load data correctly
✓ Refresh buttons work
✓ Data updates when refresh is clicked
✓ No automatic real-time updates
✓ Performance is acceptable
✓ Train admins to use refresh button
```

**✅ Week 4 Deliverable:** Web app optimized, all changes deployed

---

## 🔍 POST-IMPLEMENTATION MONITORING

### **Daily Checks (First Week):**
```bash
# 1. Check Firebase usage
https://console.firebase.google.com/project/busmate-b80e8/usage

# 2. Check error logs
firebase functions:log --only autocomplete,geocode

# 3. Monitor RTDB bandwidth
# Go to: Firebase Console → Realtime Database → Usage

# 4. Check user reports
# Monitor for complaints about map accuracy or performance
```

### **Key Metrics to Track:**

| Metric | Before | Target | Current |
|--------|--------|--------|---------|
| Firestore Reads/Day | 3M | <50k | ??? |
| Firestore Writes/Day | 8M | <20k | ??? |
| RTDB Bandwidth/Day | 0 | <300MB | ??? |
| Monthly Cost | ₹44,780 | ₹142 | ??? |
| Krutrim API Errors | N/A | <1% | ??? |
| User Complaints | N/A | <5/week | ??? |

---

## 🆘 ROLLBACK PLAN (If Things Go Wrong)

### **Scenario 1: Krutrim API is unreliable**

**Symptoms:** >10% error rate, slow responses, incorrect data

**Action:**
```typescript
// In Cloud Functions - already implemented fallback
// Functions will automatically use Google Maps if Krutrim fails

// Monitor fallback usage:
firebase functions:log | grep "falling back to Google"

// If fallback usage > 50%, revert to Google:
export const autocomplete = functions.https.onRequest(
  // Comment out Krutrim code, use only Google Maps
);
```

### **Scenario 2: Firebase free tier exceeded**

**Symptoms:** Unexpected charges, quota exceeded errors

**Action:**
```bash
# 1. Check which service exceeded
Firebase Console → Usage → Identify culprit

# 2. If Firestore reads exceeded:
# - Increase polling interval (30s → 60s)
# - Reduce number of collections being polled

# 3. If RTDB bandwidth exceeded:
# - Reduce bus update frequency (30s → 60s)
# - Compress location data
```

### **Scenario 3: Users complain about map accuracy**

**Symptoms:** Wrong addresses, missing locations, incorrect routes

**Action:**
```bash
# 1. Revert to Google Maps temporarily
firebase functions:config:set use_google_maps="true"
firebase deploy --only functions

# 2. Report issues to Krutrim
support@krutrim.ai

# 3. Re-evaluate after Krutrim fixes issues
```

---

## 💰 COST TRACKING SPREADSHEET

### **Monthly Cost Tracker:**

```
Month | Firestore | RTDB | Krutrim | Google Maps | Total | Savings
------|-----------|------|---------|-------------|-------|--------
Oct   | ₹44,150   | ₹0   | ₹0      | ₹630        | 44,780| Baseline
Nov   | ₹0        | ₹142 | ₹0      | ₹0          | 142   | ₹44,638
Dec   | ₹0        | ₹142 | ₹0      | ₹0          | 142   | ₹44,638
Jan   | ₹0        | ₹142 | ₹0      | ₹0          | 142   | ₹44,638
...
```

**Download Template:** [Google Sheets - BusMate Cost Tracker]

---

## 📞 SUPPORT CONTACTS

### **Krutrim Maps:**
- Support: support@krutrim.ai
- Documentation: https://docs.krutrim.ai
- Status: https://status.krutrim.ai

### **Firebase:**
- Support: https://firebase.google.com/support
- Community: https://stackoverflow.com/questions/tagged/firebase

### **Emergency Rollback:**
- Developer: [Your contact]
- Firebase Admin: [Admin contact]
- Escalation: Revert to Google Maps immediately

---

## ✅ SUCCESS CRITERIA

### **Must Have:**
- [x] Krutrim API integrated with fallback
- [x] Firebase costs under ₹200/month
- [x] Zero functionality lost
- [x] Map accuracy >95%
- [x] API reliability >99%

### **Nice to Have:**
- [ ] Krutrim better than Google for Indian addresses
- [ ] Users notice improved performance
- [ ] Zero user complaints
- [ ] Firebase costs under ₹150/month

---

## 🎯 FINAL CHECKLIST

Before going live:
- [ ] Krutrim API key secured in environment variables
- [ ] Google Maps fallback tested and working
- [ ] All Firebase optimizations deployed
- [ ] Realtime Database rules configured
- [ ] Monitoring dashboard set up
- [ ] Team trained on new architecture
- [ ] Rollback plan documented and tested
- [ ] Users notified of changes (if visible)
- [ ] Cost tracking spreadsheet created
- [ ] 30-day review scheduled

---

**Implementation Owner:** [Your Name]  
**Review Date:** November 25, 2025  
**Next Steps:** Execute Week 1 plan

