# 🛰️ GPS Source Separation Strategy

## Overview
This document explains how to handle multiple GPS sources (driver phone vs hardware GPS device) in the BusMate system.

---

## 📊 Architecture

### **1. GPS Source Configuration**

Add to Firestore `buses/{busId}` collection:

```json
{
  "busId": "BUS_001",
  "vehicleNumber": "TN - 07 - 87qbadf",
  "schoolId": "SCH1761403353624",
  
  // GPS Configuration
  "gpsConfig": {
    "sourceType": "hardware",        // "hardware", "software", or "auto"
    "priority": "hardware",          // Which source takes precedence
    "hardwareDeviceId": "HW_12345",  // Hardware GPS device ID
    "allowDriverGPS": false,         // Allow driver phone as fallback
    "autoSwitchOnFailure": true      // Auto-switch if primary fails
  },
  
  "lastGPSUpdate": {
    "timestamp": "2025-11-30T10:00:00Z",
    "source": "hardware",            // Which source sent this
    "latitude": 11.002568,
    "longitude": 77.058916,
    "accuracy": 5.0,                 // GPS accuracy in meters
    "deviceId": "HW_12345"
  }
}
```

---

## 🔧 Implementation Methods

### **Method 1: Firestore-Based Validation (Recommended)**

**Location update flow:**

```dart
// When GPS data arrives (from either source)
Future<void> updateBusLocation({
  required String busId,
  required double latitude,
  required double longitude,
  required String sourceType,  // "hardware" or "software"
  required String deviceId,    // Hardware device ID or driver phone ID
}) async {
  // 1. Get bus configuration
  final busDoc = await FirebaseFirestore.instance
    .collection('buses')
    .doc(busId)
    .get();
  
  final gpsConfig = busDoc.data()?['gpsConfig'];
  final allowedSource = gpsConfig?['sourceType'] ?? 'software';
  final priority = gpsConfig?['priority'] ?? 'software';
  
  // 2. Validate source
  if (!_isSourceAllowed(sourceType, allowedSource, priority)) {
    print('⚠️ GPS update rejected: Source $sourceType not allowed for bus $busId');
    return;
  }
  
  // 3. Update location in Realtime Database
  await FirebaseDatabase.instance
    .ref('bus_locations/$schoolId/$busId')
    .update({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': ServerValue.timestamp,
      'source': sourceType,
      'deviceId': deviceId,
    });
  
  // 4. Update last GPS info in Firestore
  await FirebaseFirestore.instance
    .collection('buses')
    .doc(busId)
    .update({
      'lastGPSUpdate': {
        'timestamp': FieldValue.serverTimestamp(),
        'source': sourceType,
        'latitude': latitude,
        'longitude': longitude,
        'deviceId': deviceId,
      }
    });
}

bool _isSourceAllowed(String sourceType, String allowedSource, String priority) {
  // Auto mode: Accept both, prioritize based on priority setting
  if (allowedSource == 'auto') {
    return true;
  }
  
  // Strict mode: Only accept configured source
  return sourceType == allowedSource;
}
```

---

### **Method 2: Separate Realtime Database Paths**

Store GPS data from different sources in separate paths:

```
bus_locations/
  {schoolId}/
    {busId}/
      hardware/          ← Hardware GPS data
        latitude: 11.002568
        longitude: 77.058916
        timestamp: 1701342000000
        deviceId: "HW_12345"
        accuracy: 5.0
      
      software/          ← Driver phone GPS data
        latitude: 11.002570
        longitude: 77.058918
        timestamp: 1701342005000
        driverId: "DRIVER_001"
        accuracy: 10.0
      
      active/            ← Active GPS source (automatically selected)
        latitude: 11.002568
        longitude: 77.058916
        timestamp: 1701342000000
        source: "hardware"
        deviceId: "HW_12345"
```

**Implementation:**

```dart
// Hardware GPS device sends to:
FirebaseDatabase.instance
  .ref('bus_locations/$schoolId/$busId/hardware')
  .set({
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': ServerValue.timestamp,
    'deviceId': hardwareDeviceId,
    'accuracy': accuracy,
  });

// Driver phone sends to:
FirebaseDatabase.instance
  .ref('bus_locations/$schoolId/$busId/software')
  .set({
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': ServerValue.timestamp,
    'driverId': driverId,
    'accuracy': accuracy,
  });

// Cloud Function merges and selects best source:
exports.selectActiveGPSSource = functions.database
  .ref('bus_locations/{schoolId}/{busId}/{source}')
  .onWrite(async (change, context) => {
    const { schoolId, busId, source } = context.params;
    
    // Get bus configuration
    const busDoc = await admin.firestore()
      .collection('buses')
      .doc(busId)
      .get();
    
    const gpsConfig = busDoc.data().gpsConfig;
    const priority = gpsConfig.priority;
    
    // Get both sources
    const hardwareSnap = await admin.database()
      .ref(`bus_locations/${schoolId}/${busId}/hardware`)
      .once('value');
    const softwareSnap = await admin.database()
      .ref(`bus_locations/${schoolId}/${busId}/software`)
      .once('value');
    
    const hardwareData = hardwareSnap.val();
    const softwareData = softwareSnap.val();
    
    // Select active source based on priority and freshness
    let activeData = null;
    
    if (priority === 'hardware' && hardwareData) {
      // Check if hardware data is fresh (< 30 seconds old)
      const hardwareAge = Date.now() - hardwareData.timestamp;
      if (hardwareAge < 30000) {
        activeData = { ...hardwareData, source: 'hardware' };
      } else if (softwareData) {
        activeData = { ...softwareData, source: 'software' };
      }
    } else if (priority === 'software' && softwareData) {
      activeData = { ...softwareData, source: 'software' };
    } else {
      // Auto mode: Use most recent
      if (hardwareData && softwareData) {
        activeData = hardwareData.timestamp > softwareData.timestamp
          ? { ...hardwareData, source: 'hardware' }
          : { ...softwareData, source: 'software' };
      } else {
        activeData = hardwareData || softwareData;
      }
    }
    
    // Update active location
    if (activeData) {
      await admin.database()
        .ref(`bus_locations/${schoolId}/${busId}/active`)
        .set(activeData);
    }
  });
```

---

### **Method 3: Device Authentication (Most Secure)**

Use device tokens to authenticate GPS sources:

```dart
// 1. Register hardware device in Firestore
await FirebaseFirestore.instance
  .collection('gps_devices')
  .doc('HW_12345')
  .set({
    'deviceId': 'HW_12345',
    'type': 'hardware',
    'assignedBusId': 'BUS_001',
    'authToken': 'secure_token_12345',
    'isActive': true,
    'lastSeen': FieldValue.serverTimestamp(),
  });

// 2. Hardware GPS sends data with auth token
final response = await http.post(
  Uri.parse('https://your-cloud-function.com/updateGPS'),
  headers: {
    'Authorization': 'Bearer secure_token_12345',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'deviceId': 'HW_12345',
    'busId': 'BUS_001',
    'latitude': 11.002568,
    'longitude': 77.058916,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);

// 3. Cloud Function validates and updates
exports.updateGPS = functions.https.onRequest(async (req, res) => {
  const authToken = req.headers.authorization?.split('Bearer ')[1];
  const { deviceId, busId, latitude, longitude } = req.body;
  
  // Validate device token
  const deviceDoc = await admin.firestore()
    .collection('gps_devices')
    .doc(deviceId)
    .get();
  
  if (!deviceDoc.exists || deviceDoc.data().authToken !== authToken) {
    return res.status(401).send('Unauthorized device');
  }
  
  if (deviceDoc.data().assignedBusId !== busId) {
    return res.status(403).send('Device not assigned to this bus');
  }
  
  // Update location
  await admin.database()
    .ref(`bus_locations/${busId}/hardware`)
    .set({
      latitude,
      longitude,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      deviceId,
    });
  
  res.status(200).send('GPS updated');
});
```

---

## 🎯 Recommended Strategy for BusMate

### **Phase 1: Start with Software GPS (Driver Phone)**
- ✅ Already implemented in `busmate_app`
- ✅ Works out of the box
- ✅ No additional hardware cost
- ✅ Easy to deploy

### **Phase 2: Add Hardware GPS Support**
When schools want to upgrade:

1. **Add `gpsConfig` to bus documents:**
   ```dart
   "gpsConfig": {
     "sourceType": "hardware",
     "hardwareDeviceId": "HW_12345",
     "allowDriverGPS": true,  // Fallback if hardware fails
   }
   ```

2. **Hardware GPS device configuration:**
   - Configure device to send HTTP POST to Cloud Function
   - Include device authentication token
   - Send data every 3-5 seconds

3. **Cloud Function handles both:**
   ```javascript
   // Prioritize hardware GPS
   // Fall back to driver phone if hardware offline
   ```

### **Phase 3: Hybrid Mode (Best of Both)**
- Hardware GPS for accuracy
- Driver phone GPS as backup
- Automatic failover
- Real-time monitoring dashboard

---

## 📱 Driver App Changes

### Current Implementation (Software GPS):
```dart
// In busmate_app/lib/location_callback_handler.dart
await FirebaseDatabase.instance
  .ref('bus_locations/$schoolId/$busId')
  .set(location.toRealtimeDb());
```

### Modified Implementation (Check GPS Config):
```dart
Future<void> updateLocationFromDriverPhone(BusLocation location) async {
  // Check if driver GPS is allowed for this bus
  final busDoc = await FirebaseFirestore.instance
    .collection('buses')
    .doc(location.busId)
    .get();
  
  final gpsConfig = busDoc.data()?['gpsConfig'];
  final sourceType = gpsConfig?['sourceType'] ?? 'software';
  
  // If hardware GPS is configured, check if driver GPS is allowed
  if (sourceType == 'hardware') {
    final allowDriverGPS = gpsConfig?['allowDriverGPS'] ?? false;
    if (!allowDriverGPS) {
      print('⚠️ Driver GPS disabled for this bus - using hardware GPS only');
      return;
    }
  }
  
  // Update to software path
  await FirebaseDatabase.instance
    .ref('bus_locations/$schoolId/$busId/software')
    .set({
      ...location.toRealtimeDb(),
      'source': 'software',
      'driverId': driverId,
    });
}
```

---

## 🔌 Hardware GPS Integration Example

### HTTP-based Hardware GPS Device:

```javascript
// Hardware GPS device sends POST request every 5 seconds
const axios = require('axios');

setInterval(async () => {
  const gpsData = getGPSData(); // From GPS module
  
  try {
    await axios.post('https://your-cloud-function.com/updateGPS', {
      deviceId: 'HW_12345',
      busId: 'BUS_001',
      latitude: gpsData.latitude,
      longitude: gpsData.longitude,
      speed: gpsData.speed,
      heading: gpsData.heading,
      accuracy: gpsData.accuracy,
      timestamp: new Date().toISOString(),
    }, {
      headers: {
        'Authorization': 'Bearer secure_token_12345',
      }
    });
    
    console.log('GPS data sent successfully');
  } catch (error) {
    console.error('Failed to send GPS data:', error);
  }
}, 5000);
```

---

## 📊 Admin Dashboard - GPS Source Management

Add to web admin panel:

```dart
// GPS Source Selector for each bus
DropdownButton<String>(
  value: bus.gpsConfig.sourceType,
  items: [
    DropdownMenuItem(value: 'software', child: Text('📱 Driver Phone')),
    DropdownMenuItem(value: 'hardware', child: Text('🔧 Hardware GPS')),
    DropdownMenuItem(value: 'auto', child: Text('🔄 Auto (Best Available)')),
  ],
  onChanged: (value) async {
    await FirebaseFirestore.instance
      .collection('buses')
      .doc(bus.busId)
      .update({
        'gpsConfig.sourceType': value,
      });
  },
);

// Show active GPS source status
Row(
  children: [
    Icon(
      bus.lastGPSUpdate.source == 'hardware' 
        ? Icons.router 
        : Icons.phone_android,
      color: Colors.green,
    ),
    Text('Active: ${bus.lastGPSUpdate.source}'),
    Text('Updated: ${timeAgo(bus.lastGPSUpdate.timestamp)}'),
  ],
);
```

---

## ✅ Summary

**For your current BusMate system:**

1. **Start with software GPS** (already working! ✅)
   - Driver phone provides location
   - No additional cost
   - Easy deployment

2. **Add hardware GPS support later** (when needed)
   - Add `gpsConfig` field to buses
   - Create Cloud Function to handle hardware GPS updates
   - Configure hardware devices with auth tokens

3. **Use separate Realtime Database paths:**
   - `bus_locations/{schoolId}/{busId}/software` ← Driver phone
   - `bus_locations/{schoolId}/{busId}/hardware` ← Hardware GPS
   - `bus_locations/{schoolId}/{busId}/active` ← Active source (auto-selected)

4. **Admin dashboard controls:**
   - Select GPS source per bus
   - Monitor both sources
   - See which is active

**The system is already working perfectly with driver phones! Hardware GPS can be added later without disrupting existing functionality.** 🚀

