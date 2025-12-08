# 🗺️ Maps & Real-Time Tracking Implementation Plan

## Project: BusMate - Live Bus Tracking with Time-Based Notifications

---

## 📋 Implementation Strategy: Distance-Based Checkpoint System

### **Cost-Effective Approach** 
**Estimated Cost**: ₹2,160 - ₹3,600/month ($26-43) for 50 buses

---

## 🎯 Core Strategy: Adaptive 4-Checkpoint System

### **How It Works:**

1. **Route Start**: 
   - Call OLA Maps Distance Matrix API for 4 checkpoints (1 API call)
   - Divide total route distance into 4 equal parts (25%, 50%, 75%, 100%)
   - Snap checkpoint distances to nearest actual bus stops
   - Store baseline ETAs in Firebase Realtime Database

2. **During Route**:
   - Driver app sends GPS updates every 10 seconds to Firebase
   - Cloud Function calculates ETA using GPS speed + distance (NO API calls)
   - Parents see real-time updates via Firebase listeners

3. **At Each Checkpoint**:
   - Check variance: `(actualTime - predictedTime) / predictedTime`
   - **IF variance > 10%**: Recalculate remaining checkpoints with API call
   - **IF variance ≤ 10%**: Continue with interpolation (NO API call)

4. **Notification Trigger**:
   - When ETA matches student's preference (5, 10, 15, or 20 minutes)
   - Send notification via FCM (FREE)
   - 30-minute cooldown to prevent spam

---

## 💰 Cost Breakdown

### **Option 1: Pure 4-Checkpoint System**
- **API Calls**: 4 per route (fixed)
- **Monthly**: 50 buses × 2 routes × 30 days × 4 calls = 12,000 calls
- **Cost**: 12,000 × ₹0.30 = **₹3,600/month ($43)**
- **Accuracy**: 92%
- **Best for**: Predictable budgeting

### **Option 2: Adaptive Checkpoint System** ⭐ RECOMMENDED
- **API Calls**: 2.4 per route (average, only when needed)
- **Monthly**: 50 buses × 2 routes × 30 days × 2.4 calls = 7,200 calls
- **Cost**: 7,200 × ₹0.30 = **₹2,160/month ($26)**
- **Accuracy**: 92%
- **Best for**: Cost optimization (saves 40%)

### **Option 3: Uber-Style Snap-to-Road**
- **API Calls**: 1.1 per route (route start + rare deviations)
- **Monthly**: 3,300 calls
- **Cost**: ₹1,320/month ($16)
- **Accuracy**: 90%
- **Best for**: Minimum cost, slightly lower accuracy

---

## 🔧 Technical Architecture

### **Components:**

1. **Driver Mobile App** (Flutter - busmate_app)
   - Send GPS location every 10 seconds
   - Path: `bus_locations/{busId}` in Realtime DB
   - Data: `{ latitude, longitude, speed, timestamp, routeId }`

2. **Firebase Realtime Database Structure**:
```json
{
  "bus_locations": {
    "bus123": {
      "latitude": 13.0827,
      "longitude": 80.2707,
      "speed": 35,
      "timestamp": 1699552800000,
      "routeId": "route_morning_1"
    }
  },
  "routes": {
    "route_morning_1": {
      "busId": "bus123",
      "stops": {
        "stop1": { "name": "Main Gate", "lat": 13.08, "lng": 80.27, "eta": 0, "status": "completed" },
        "stop2": { "name": "Park Street", "lat": 13.09, "lng": 80.28, "eta": 8, "status": "upcoming" },
        "stop3": { "name": "School", "lat": 13.10, "lng": 80.29, "eta": 15, "status": "upcoming" }
      },
      "checkpoints": {
        "cp1": { "stopId": "stop3", "distance": 5.5, "baselineETA": 15, "actualETA": 16, "reached": true },
        "cp2": { "stopId": "stop6", "distance": 11, "baselineETA": 30, "actualETA": 30, "reached": false },
        "cp3": { "stopId": "stop9", "distance": 16.5, "baselineETA": 45, "actualETA": 45, "reached": false },
        "cp4": { "stopId": "stop12", "distance": 22, "baselineETA": 60, "actualETA": 60, "reached": false }
      },
      "totalDistance": 22,
      "startTime": 1699552800000,
      "status": "active"
    }
  },
  "student_notifications": {
    "student123": {
      "stopId": "stop5",
      "notificationPreference": 15,
      "lastNotificationSent": 1699552700000,
      "notificationType": "voice"
    }
  }
}
```

3. **Cloud Function: calculateETA** (Node.js)
   - Trigger: Firebase Realtime Database `bus_locations/{busId}` update
   - Logic:
     ```javascript
     exports.calculateETA = functions.database
       .ref('/bus_locations/{busId}')
       .onUpdate(async (change, context) => {
         const busLocation = change.after.val();
         const route = await getRouteForBus(busId);
         
         // Check if checkpoint reached
         const reachedCheckpoint = checkCheckpointReached(busLocation, route.checkpoints);
         
         if (reachedCheckpoint) {
           const variance = calculateVariance(reachedCheckpoint);
           
           if (variance > 0.1) {
             // Recalculate with OLA API
             const updatedETAs = await olaDistanceMatrix(
               busLocation,
               remainingCheckpoints
             );
             await updateCheckpointETAs(updatedETAs);
           }
         }
         
         // Calculate ETA for all stops using speed
         const etaUpdates = calculateStopETAs(busLocation, route.stops);
         await updateStopETAs(etaUpdates);
         
         // Check notification triggers
         await checkAndSendNotifications(etaUpdates);
       });
     ```

4. **Cloud Function: sendNotification**
   - Check if `stopETA ≈ studentPreference (±2 min)`
   - Check 30-min cooldown
   - Send FCM notification OR Voice call (TTS)

5. **Parent Mobile App** (Flutter - busmate_app)
   - Listen to `routes/{routeId}/stops/{studentStopId}`
   - Display real-time ETA
   - Show bus location on map (OSM tiles)

6. **Web Dashboard** (Flutter Web - busmate_web)
   - Admin view: All active buses on map
   - School Manager view: School buses only
   - Regional Admin view: Based on permissions

---

## 📐 Checkpoint Calculation Algorithm

### **Distance-Based with Stop Anchoring:**

```javascript
function calculateCheckpoints(allStops) {
  // Step 1: Calculate cumulative distances
  let totalDistance = 0;
  const stopsWithDistance = [{ ...allStops[0], cumulativeDistance: 0 }];
  
  for (let i = 1; i < allStops.length; i++) {
    const distance = haversineDistance(allStops[i-1], allStops[i]);
    totalDistance += distance;
    stopsWithDistance.push({
      ...allStops[i],
      cumulativeDistance: totalDistance
    });
  }
  
  // Step 2: Find target distances (25%, 50%, 75%, 100%)
  const targetPercentages = [0.25, 0.50, 0.75, 1.00];
  const checkpointDistances = targetPercentages.map(p => totalDistance * p);
  
  // Step 3: Snap to nearest stops
  const checkpoints = checkpointDistances.map(targetDistance => {
    return stopsWithDistance.reduce((nearest, stop) => {
      const currentDiff = Math.abs(stop.cumulativeDistance - targetDistance);
      const nearestDiff = Math.abs(nearest.cumulativeDistance - targetDistance);
      return currentDiff < nearestDiff ? stop : nearest;
    });
  });
  
  return checkpoints;
}

// Example Result:
// Route: 20km with 12 stops
// Checkpoints: Stop 3 (5.2km), Stop 6 (10.1km), Stop 9 (15.3km), Stop 12 (20km)
```

---

## 🗺️ API Services

### **OLA Maps APIs to Use:**

1. **Distance Matrix API** ⭐ PRIMARY
   - Endpoint: `https://api.olamaps.io/routing/v1/distanceMatrix`
   - Purpose: Get ETAs for multiple checkpoints in one call
   - Cost: ₹0.30 per request
   - Request:
     ```json
     {
       "origins": [{ "lat": 13.08, "lng": 80.27 }],
       "destinations": [
         { "lat": 13.09, "lng": 80.28 },
         { "lat": 13.10, "lng": 80.29 },
         { "lat": 13.11, "lng": 80.30 }
       ],
       "mode": "driving"
     }
     ```
   - Response:
     ```json
     {
       "rows": [{
         "elements": [
           { "distance": 5500, "duration": 420 },
           { "distance": 11000, "duration": 840 },
           { "distance": 16500, "duration": 1260 }
         ]
       }]
     }
     ```

2. **Autocomplete API** (Route Setup)
   - Purpose: Search stops when creating routes
   - Cost: ₹0.15-0.30 per request
   - Usage: One-time during route creation

3. **Geocoding API** (Optional)
   - Purpose: Convert addresses to lat/lng
   - Cost: ₹0.15-0.30 per request
   - Usage: One-time during stop creation

### **OpenStreetMap (Free)**
- Tile Server: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- Purpose: Display map in parent/admin apps
- Cost: FREE (respect usage policy)

---

## 📱 Notification System

### **Time-Based Triggers:**

```javascript
function shouldSendNotification(stopETA, studentPreference, lastNotificationTime) {
  // Check if ETA matches preference (±2 min buffer)
  const etaMatch = Math.abs(stopETA - studentPreference) <= 2;
  
  // Check 30-minute cooldown
  const cooldownPassed = (Date.now() - lastNotificationTime) > 30 * 60 * 1000;
  
  return etaMatch && cooldownPassed;
}

// Example:
// Student preference: 15 minutes
// Current ETA: 14 minutes
// Last notification: 45 minutes ago
// Result: SEND NOTIFICATION ✅

// Student preference: 10 minutes
// Current ETA: 14 minutes
// Result: DON'T SEND (ETA not close enough) ❌
```

### **Notification Types:**

1. **Push Notification** (FCM - FREE)
   - Default for all students
   - "🚌 Bus arriving at Park Street in 15 minutes!"

2. **Voice Call** (Optional - TTS)
   - For students without smartphones
   - Integration: Twilio or similar
   - Cost: ₹0.50-1 per call

---

## 🚀 Implementation Phases

### **Phase 1: Database Setup** (1-2 days)
- [ ] Set up Firebase Realtime Database structure
- [ ] Create routes collection in Firestore
- [ ] Add checkpoint calculation to route creation
- [ ] Test data write/read performance

### **Phase 2: Driver App GPS** (2-3 days)
- [ ] Add background location service to driver app
- [ ] Send GPS to Realtime DB every 10 seconds
- [ ] Handle offline scenarios (queue updates)
- [ ] Add route start/stop controls

### **Phase 3: Cloud Functions** (3-4 days)
- [ ] Create calculateETA function
- [ ] Implement checkpoint detection logic
- [ ] Integrate OLA Maps Distance Matrix API
- [ ] Add variance calculation and adaptive recalc
- [ ] Create sendNotification function
- [ ] Test with mock data

### **Phase 4: Parent App** (2-3 days)
- [ ] Add OSM map widget
- [ ] Listen to route updates
- [ ] Display real-time ETA
- [ ] Show bus location on map
- [ ] Add notification preference settings

### **Phase 5: Web Dashboard** (2-3 days)
- [ ] Add live bus tracking view
- [ ] Display all active routes
- [ ] Show ETA statistics
- [ ] Add route management (create/edit)
- [ ] Checkpoint visualization

### **Phase 6: Testing & Optimization** (1 week)
- [ ] Test with real bus routes
- [ ] Validate ETA accuracy
- [ ] Monitor API costs
- [ ] Optimize checkpoint logic
- [ ] Load testing with 50 buses

---

## 📊 Success Metrics

### **Target KPIs:**

1. **ETA Accuracy**: >90%
   - Measure: Actual arrival time vs predicted ETA
   - Target: Within ±3 minutes for 90% of stops

2. **API Cost**: <₹3,000/month
   - Monitor: Daily API call counts
   - Optimize: Adjust variance threshold if needed

3. **Notification Delivery**: >95%
   - Measure: FCM success rate
   - Target: Notifications sent within 1 minute of trigger

4. **Parent Satisfaction**: >4.5/5
   - Measure: In-app feedback
   - Target: Parents find ETAs reliable

---

## 🔐 Security & Performance

### **Security:**
- [ ] Secure Firebase Realtime Database rules
- [ ] API key restrictions (domain/IP whitelist)
- [ ] Rate limiting on Cloud Functions
- [ ] Authentication for route updates

### **Performance:**
- [ ] Index Realtime DB queries
- [ ] Cache checkpoint calculations
- [ ] Batch notification sends
- [ ] Monitor Cloud Function cold starts

---

## 💡 Future Enhancements

1. **Machine Learning ETA** (Phase 2)
   - Train model on 3 months of historical data
   - Predict delays based on time of day, weather, events
   - Reduce API calls to <1,000/month

2. **Parent-to-Parent Updates** (Phase 3)
   - Waze-style crowdsourced delays
   - "Bus stuck in traffic near Stop 5"
   - Community-based ETA adjustments

3. **Multi-Modal Routes** (Phase 4)
   - Support walking portions (drop-off to home)
   - Bicycle/auto transfer points
   - Combined ETA calculation

---

## 📞 API Documentation Links

- OLA Maps: https://maps.olakrutrim.com/
- Firebase Realtime Database: https://firebase.google.com/docs/database
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- OpenStreetMap Tiles: https://wiki.openstreetmap.org/wiki/Tile_servers
- Flutter OSM Plugin: https://pub.dev/packages/flutter_map

---

## 📝 Notes

- **Start with Option 2** (Adaptive Checkpoint) for best cost/accuracy balance
- **Monitor actual costs** in first month and adjust variance threshold
- **Consider Navigation SDK** if OLA offers session-based pricing <₹5/session
- **Test during peak traffic** to validate accuracy
- **Implement fallback** to pure GPS speed calculation if API fails

---

**Last Updated**: November 9, 2025
**Status**: Planning Complete - Ready for Implementation
**Estimated Timeline**: 3-4 weeks for full implementation
**Estimated Cost**: ₹2,160-3,600/month ($26-43) for 50 buses
