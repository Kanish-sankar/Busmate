# 🧪 Ola Maps ETA System - Testing Guide

This guide explains how to test the Ola Maps segment-based ETA system and understand what's happening.

---

## 📊 **Method 1: Console Logging (Already Implemented)**

I've added comprehensive debug logging to track everything. Here's what you'll see:

### **When ETA Calculation Happens:**
```
🔍 [ETA] Starting updateETAs - Remaining stops: 8
🎯 [SEGMENTS] Initialized 4 segments for 8 stops
   Segment 1: 2 stops (indices 0-1)
   Segment 2: 2 stops (indices 2-3)
   Segment 3: 2 stops (indices 4-5)
   Segment 4: 2 stops (indices 6-7)
🚀 [OLA MAPS] Recalculation triggered:
   - Total stops: 8
   - Stops passed: 0
   - Current segment: 1

🚀 [OLA MAPS API] Calculating ETAs:
   - Total stops: 8
   - Total waypoints: 0
   - Total destinations in ONE call: 8
   - Stop indices: [0, 1, 2, 3, 4, 5, 6, 7]
   ✅ API call successful - received 8 results
   📍 Stop 1: 5.2min, 2.34km
   📍 Stop 2: 8.7min, 3.89km
   📍 Stop 3: 12.3min, 5.45km
   📍 Stop 4: 15.8min, 7.12km
   📍 Stop 5: 19.4min, 8.67km
   📍 Stop 6: 22.9min, 10.23km
   📍 Stop 7: 26.5min, 11.78km
   📍 Stop 8: 30.1min, 13.34km
   🎯 Initial ETA calculation complete: 8/8 stops

✅ [ETA] Ola Maps ETAs updated successfully at 2025-11-30T14:23:45.000
```

### **When Bus Passes Stops:**
```
🔍 [SEGMENT CHECK] Checking segment completion...
   - Current segment: 1/4
   - Stops passed: 0/8
   - Checking segment 1 (stops 0-1)
   ✓ Stop 1 within 50m: Main Street Bus Stop
   ✓ Stop 2 within 50m: Park Avenue
   📍 Stops passed updated: 0 → 2

🎉 [SEGMENT COMPLETE] Segment 1 finished!
   - Stops in segment: 0-1
   - Total stops passed: 2
   ➡️ Moving to segment 2
   📡 Triggering ETA recalculation...
```

### **When ETAs Are Recalculated:**
```
🔄 [OLA MAPS RECALC] Recalculating ETAs:
   - Stops passed: 2
   - Remaining stops: 6

🚀 [OLA MAPS API] Calculating ETAs:
   - Total stops: 6
   - Total waypoints: 0
   - Total destinations in ONE call: 6
   📍 Stop 3: 3.2min, 1.45km (updated!)
   📍 Stop 4: 6.8min, 2.89km (updated!)
   📍 Stop 5: 10.4min, 4.34km (updated!)
   ...
   ✅ Recalculation complete: 6 ETAs updated
```

### **When Notifications Are Checked:**
```
   📲 [NOTIFY] First notification for Park Avenue
   ⏭️ [SKIP NOTIFY] ETA unchanged for Main Street (1min diff)
   📲 [NOTIFY] ETA changed for Oak Road: 5min difference
      Old ETA: 2025-11-30T14:45:00.000
      New ETA: 2025-11-30T14:50:00.000
```

---

## 🖥️ **Method 2: View Logs in Flutter DevTools**

### **Step 1: Run the App**
```powershell
cd busmate_app
flutter run -d chrome
```

### **Step 2: Open Flutter DevTools**
1. When the app runs, look for this message in terminal:
   ```
   An Observatory debugger and profiler on Chrome is available at: http://127.0.0.1:xxxxx/
   The Flutter DevTools debugger and profiler on Chrome is available at: http://127.0.0.1:xxxxx/
   ```

2. Click the DevTools link or press **`v`** in the terminal

3. Go to **Logging** tab

4. You'll see all the logs with emojis and colors!

---

## 📱 **Method 3: Firestore Console (Real-time Data)**

### **What to Check:**

1. **Go to Firebase Console** → **Firestore Database**

2. **Navigate to:** `bus_status/{busId}`

3. **Watch these fields update in real-time:**

   ```json
   {
     "segments": [
       {
         "number": 1,
         "startStopIndex": 0,
         "endStopIndex": 1,
         "status": "completed",
         "completedAt": "2025-11-30T14:25:00.000Z"
       },
       {
         "number": 2,
         "startStopIndex": 2,
         "endStopIndex": 3,
         "status": "in_progress"
       },
       {
         "number": 3,
         "startStopIndex": 4,
         "endStopIndex": 5,
         "status": "pending"
       },
       {
         "number": 4,
         "startStopIndex": 6,
         "endStopIndex": 7,
         "status": "pending"
       }
     ],
     "currentSegmentNumber": 2,
     "stopsPassedCount": 2,
     "lastETACalculation": "2025-11-30T14:25:30.000Z",
     "lastNotifiedETAs": {
       "Main Street": "2025-11-30T14:20:00.000Z",
       "Park Avenue": "2025-11-30T14:23:00.000Z"
     },
     "remainingStops": [
       {
         "name": "Oak Road",
         "latitude": 12.9716,
         "longitude": 77.5946,
         "distanceToStop": 1450,
         "estimatedMinutesOfArrival": 3.2,
         "estimatedTimeOfArrival": "2025-11-30T14:28:42.000Z"
       }
       // ... more stops
     ]
   }
   ```

4. **Watch what changes when:**
   - ✅ Bus starts trip → `segments` array created, `currentSegmentNumber = 1`
   - ✅ Bus passes stop 1 → `stopsPassedCount` increments
   - ✅ Bus completes segment 1 → `segments[0].status = "completed"`, `currentSegmentNumber = 2`
   - ✅ ETA recalculation happens → `lastETACalculation` updates, all `remainingStops` ETAs change
   - ✅ Parent notified → `lastNotifiedETAs["Stop Name"]` updates

---

## 🧮 **Method 4: Test Different Route Configurations**

### **Test Case 1: 8 Stops (4 segments)**
Expected segmentation:
- Segment 1: Stops 0-1 (2 stops)
- Segment 2: Stops 2-3 (2 stops)
- Segment 3: Stops 4-5 (2 stops)
- Segment 4: Stops 6-7 (2 stops)

**Logs to watch for:**
```
🎯 [SEGMENTS] Initialized 4 segments for 8 stops
   Segment 1: 2 stops (indices 0-1)
   Segment 2: 2 stops (indices 2-3)
   Segment 3: 2 stops (indices 4-5)
   Segment 4: 2 stops (indices 6-7)
```

### **Test Case 2: 13 Stops (4 segments)**
Expected segmentation:
- Segment 1: Stops 0-3 (4 stops)
- Segment 2: Stops 4-6 (3 stops)
- Segment 3: Stops 7-9 (3 stops)
- Segment 4: Stops 10-12 (3 stops)

### **Test Case 3: 25 Stops (5 segments)**
Expected segmentation:
- Segment 1: Stops 0-4 (5 stops)
- Segment 2: Stops 5-9 (5 stops)
- Segment 3: Stops 10-14 (5 stops)
- Segment 4: Stops 15-19 (5 stops)
- Segment 5: Stops 20-24 (5 stops)

---

## 📊 **Method 5: Monitor API Calls**

### **Check Ola Maps API Usage:**

1. **Go to Ola Maps Dashboard**
2. **Navigate to:** API Usage / Analytics
3. **Expected calls per trip:**
   - **Initial calculation:** 1 API call (all stops at once)
   - **Segment 1 completed:** 1 recalculation call
   - **Segment 2 completed:** 1 recalculation call
   - **Segment 3 completed:** 1 recalculation call
   - **Total:** 4 API calls per trip

4. **Monthly usage calculation:**
   - 50 buses × 2 trips/day × 4 calls = 400 calls/day
   - 400 × 30 days = **12,000 calls/month**
   - Free tier: 500,000 calls/month
   - **Usage: 2.4%** (well within free tier!)

---

## 🐛 **Method 6: Simulate Bus Movement (For Testing)**

### **Use the Bus Simulator:**

1. **Navigate to Admin Panel**
2. **Start Bus Simulator** (if available)
3. **Watch console logs update in real-time**
4. **Speed up simulation** to test segment completion faster

### **Or Create Test Data Manually:**

```dart
// In your testing code
final testBus = BusStatusModel(
  busId: 'TEST_BUS_001',
  latitude: 12.9716,
  longitude: 77.5946,
  remainingStops: [
    StopWithETA(name: 'Stop 1', latitude: 12.9720, longitude: 77.5950),
    StopWithETA(name: 'Stop 2', latitude: 12.9725, longitude: 77.5955),
    StopWithETA(name: 'Stop 3', latitude: 12.9730, longitude: 77.5960),
    StopWithETA(name: 'Stop 4', latitude: 12.9735, longitude: 77.5965),
    StopWithETA(name: 'Stop 5', latitude: 12.9740, longitude: 77.5970),
    StopWithETA(name: 'Stop 6', latitude: 12.9745, longitude: 77.5975),
    StopWithETA(name: 'Stop 7', latitude: 12.9750, longitude: 77.5980),
    StopWithETA(name: 'Stop 8', latitude: 12.9755, longitude: 77.5985),
  ],
);

// Trigger initial ETA calculation
await testBus.updateETAs();

// Simulate bus moving to Stop 1
testBus.latitude = 12.9720;
testBus.longitude = 77.5950;
await testBus.checkAndUpdateSegmentCompletion();

// Watch logs for segment completion and recalculation!
```

---

## ✅ **What to Verify**

### **1. Segment Initialization:**
- [ ] 8 stops → 4 segments created
- [ ] 13 stops → 4 segments created
- [ ] 25 stops → 5 segments created
- [ ] First segment marked as "in_progress"

### **2. ETA Calculation:**
- [ ] Initial calculation happens on trip start
- [ ] ONE API call for all stops
- [ ] ETAs stored in `estimatedTimeOfArrival` field
- [ ] `lastETACalculation` timestamp updated

### **3. Segment Completion:**
- [ ] Bus within 50m of stop → stop marked as passed
- [ ] Last stop in segment passed → segment marked "completed"
- [ ] Next segment marked "in_progress"
- [ ] Automatic recalculation triggered

### **4. Duplicate Notification Prevention:**
- [ ] First notification sent for each stop
- [ ] ETA change <2 min → notification skipped
- [ ] ETA change >2 min → notification sent
- [ ] `lastNotifiedETAs` map updated

### **5. API Optimization:**
- [ ] Only 4 API calls per trip (not 10+)
- [ ] Traffic-aware durations used
- [ ] Fallback to OSRM on API error

---

## 🚨 **Troubleshooting**

### **No logs appearing:**
1. Make sure you're running in **debug mode**: `flutter run -d chrome`
2. Check DevTools **Logging** tab is enabled
3. Filter logs by "OLA MAPS" or "SEGMENT" or "ETA"

### **API calls failing:**
1. Check API key is correct: `c8mw89lGYQ05uglqqr7Val5eUTMRTPqgwMNS6F7h`
2. Verify internet connectivity
3. Look for error logs: `❌ [OLA MAPS] API Error:`
4. Check if fallback to OSRM is working: `⚠️ [FALLBACK] Using OSRM calculation instead`

### **Segments not completing:**
1. Check 50m threshold is appropriate for your GPS accuracy
2. Verify `checkAndUpdateSegmentCompletion()` is called from location callback
3. Look for: `🔍 [SEGMENT CHECK] Checking segment completion...`

### **Duplicate notifications still sent:**
1. Check `lastNotifiedETAs` map in Firestore
2. Verify 2-minute threshold in `shouldNotifyParent()`
3. Look for: `⏭️ [SKIP NOTIFY]` logs

---

## 📈 **Success Indicators**

You'll know the system is working when you see:

1. **Clean logs with emojis** showing each step
2. **Firestore data updating** in real-time
3. **4 API calls per trip** (not more)
4. **Segments completing** automatically
5. **ETAs recalculating** after each segment
6. **Notifications controlled** (no spam)
7. **Zero errors** in console

---

## 🎯 **Next Steps After Testing**

Once everything works:

1. **Remove debug logs** (or reduce verbosity)
2. **Monitor production API usage** 
3. **Collect user feedback** on ETA accuracy
4. **Adjust segment count** if needed (currently 4 for ≤20 stops)
5. **Fine-tune 50m threshold** based on GPS accuracy
6. **Optimize notification timing** based on parent preferences

---

## 📞 **Need Help?**

If you encounter issues:
1. **Check console logs first** (most detailed)
2. **Verify Firestore data** (shows actual state)
3. **Test with different route sizes** (8, 13, 20, 25 stops)
4. **Monitor API usage** (should be <5k/month for 50 buses)

**All logs are now comprehensive and production-ready! 🚀**
