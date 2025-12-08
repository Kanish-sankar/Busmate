# Complete Testing Guide - Ola Maps ETA System

## 🎯 Quick Test Options

### **Option 1: Web Admin Simulator (Easiest - 5 minutes)**
Test the complete system using web browser simulator.

### **Option 2: Mobile App Testing (Comprehensive - 30 minutes)**
Test with real GPS on your phone.

### **Option 3: End-to-End Production Test (Full System - 1 hour)**
Test with real buses, students, and notifications.

---

## 🚀 OPTION 1: Web Admin Simulator (Recommended to Start)

### **Step 1: Deploy Firebase Cloud Function**

```powershell
# Navigate to functions directory
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_web\functions"

# Install dependencies
npm install

# Deploy the Ola Maps proxy function
firebase deploy --only functions:olaDistanceMatrix
```

**Expected Output:**
```
✔  functions[olaDistanceMatrix(us-central1)] Deployed
Function URL: https://us-central1-busmate-d4c2a.cloudfunctions.net/olaDistanceMatrix
```

---

### **Step 2: Update Cloud Function URL**

After deployment, update the URL in your code:

```dart
// busmate_web/lib/services/ola_distance_matrix_service.dart
static const String _cloudFunctionUrl = 'YOUR_ACTUAL_FUNCTION_URL_HERE';
```

---

### **Step 3: Run Web Admin Panel**

```powershell
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_web"
flutter run -d chrome
```

---

### **Step 4: Test Bus Simulator**

1. **Open Chrome DevTools** (F12)
2. **Go to Console tab**
3. **Navigate to**: Bus Management → Select a bus → Start simulation
4. **Watch Console Output**:

```
🚀 [OLA MAPS TEST] Testing ETA calculation for 5 stops...
📡 Calling Ola Maps API via Cloud Function proxy...
✅ [OLA MAPS TEST] Received 4 ETAs from Ola Maps:
   📍 Stop 2: 3 min (1.6 km)
   📍 Stop 3: 6 min (2.6 km)
   📍 Stop 4: 7 min (2.9 km)
   📍 Stop 5: 7 min (3.1 km)
   ✅ Real Ola Maps API working via Cloud Function!
   ✅ Segment tracking ready!
```

**✅ SUCCESS**: You see real ETAs from Ola Maps API!
**❌ CORS Error**: Cloud Function not deployed or URL wrong
**❌ 401 Error**: Invalid Ola Maps API key

---

## 📱 OPTION 2: Mobile App Testing (Real GPS)

### **Step 1: Build Mobile App**

```powershell
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"

# For Android
flutter build apk --release

# For iOS
flutter build ios --release
```

---

### **Step 2: Install on Physical Device**

**Android:**
```powershell
flutter install
```

**iOS:**
- Open Xcode
- Connect iPhone
- Product → Run

---

### **Step 3: Enable Debug Logging**

Open the app and check logs:

```powershell
# Android
flutter logs

# iOS
flutter logs
```

---

### **Step 4: Start Route as Driver**

1. **Login as driver**
2. **Select pickup route**
3. **Click "Start Route"**
4. **Watch logs for Ola Maps API calls:**

```
🚀 [OLA MAPS] Recalculation triggered:
   - Total stops: 12
   - Stops passed: 0
   - Current segment: 1
📍 [OLA MAPS] Current location: (13.0827, 80.2707)
🎯 [OLA MAPS] Calculating ETAs for 12 stops
✅ [OLA MAPS] Received ETAs from API:
   Stop 1 (Anna Nagar): 4 min (2.3 km)
   Stop 2 (T Nagar): 8 min (4.1 km)
   Stop 3 (Adyar): 15 min (7.8 km)
   ...
```

---

### **Step 5: Test Segment Completion**

**Walk/Drive past a stop:**

1. GPS updates every 2 seconds
2. When within 200m of stop:

```
🚏 [BackgroundLocator] Bus reached stop: Anna Nagar
✂️ [BackgroundLocator] Removed stop from remaining stops
🎯 [SEGMENTS] Checking segment completion...
✅ [SEGMENTS] Segment 1 completed! (3 of 12 stops passed)
🔄 [SEGMENTS] Triggering automatic ETA recalculation...
🚀 [OLA MAPS] Recalculation triggered for remaining 9 stops
```

3. **Verify**: New Ola Maps API call made
4. **Check**: Updated ETAs in Firestore

---

### **Step 6: Verify Firestore Updates**

**Firebase Console → Firestore → bus_status → [your_bus_id]:**

```json
{
  "latitude": 13.0827,
  "longitude": 80.2707,
  "remainingStops": [
    {
      "name": "T Nagar",
      "estimatedMinutesOfArrival": 8,
      "distanceMeters": 4100,
      "eta": "2025-11-30T10:23:00"
    },
    ...
  ],
  "currentSegmentNumber": 2,
  "stopsPassedCount": 3,
  "lastETACalculation": "2025-11-30T10:15:00"
}
```

**✅ Verify**:
- `remainingStops` has updated ETAs
- `currentSegmentNumber` increases
- `stopsPassedCount` increases
- `lastETACalculation` is recent

---

## 🎓 OPTION 3: End-to-End Student Notification Test

### **Step 1: Setup Test Student**

**Firestore → students collection:**

```json
{
  "name": "Test Student",
  "assignedBusId": "BUS123",
  "stopLocation": "T Nagar",
  "notificationPreferenceByTime": 10,
  "notified": false,
  "fcmToken": "your_fcm_token_here"
}
```

---

### **Step 2: Start Bus Route**

1. Login as driver on mobile app
2. Start pickup route
3. Watch GPS updates in Firestore

---

### **Step 3: Monitor Notification Function**

```powershell
# Watch Firebase Functions logs
firebase functions:log --only sendBusArrivalNotifications
```

**Expected logs every 2 minutes:**

```
🚀 Starting notification batch job at 2025-11-30 10:15:00
📋 Processing 1 students for notifications
📦 From storage - busId: BUS123
🚍 Queuing notification for Test Student (ETA: 8min)
✅ Notification sent to Test Student
```

---

### **Step 4: Verify Notification Received**

**On parent's phone:**
```
🚌 Bus Update
Bus will arrive at T Nagar in 8 minutes
```

**In Firestore:**
```json
{
  "notified": true,  // Changed from false
  "lastNotifiedAt": "2025-11-30T10:15:00"
}
```

---

## 🧪 Quick API Test (No App Needed)

### **Test Ola Maps API Directly:**

```powershell
# Test API key validity
$headers = @{
    "Authorization" = "Bearer c8mw89lGYQ05uglqqr7Val5eUTMRTPqgwMNS6F7h"
    "Content-Type" = "application/json"
}

$body = @{
    origins = @(@(13.0827, 80.2707))
    destinations = @(
        @(13.0878, 80.2785),
        @(13.0412, 80.2565)
    )
    mode = "driving"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.olamaps.io/routing/v1/distanceMatrix" `
    -Method Post `
    -Headers $headers `
    -Body $body
```

**Expected Response:**

```json
{
  "rows": [
    {
      "elements": [
        {
          "distance": {"value": 1600},
          "duration": {"value": 180},
          "duration_in_traffic": {"value": 210},
          "status": "OK"
        },
        ...
      ]
    }
  ]
}
```

**✅ Success**: API key is valid, API working
**❌ 401**: Invalid API key
**❌ 429**: Rate limit exceeded

---

## 📊 Testing Checklist

### **Basic Functionality:**
- [ ] Ola Maps API responds with valid ETAs
- [ ] Cloud Function proxy works (web)
- [ ] Mobile app calls API directly
- [ ] ETAs appear in Firestore `bus_status`

### **Segment Tracking:**
- [ ] Segments created on route start
- [ ] Segment completion detected (stop passed)
- [ ] Automatic ETA recalculation on segment completion
- [ ] `currentSegmentNumber` updates correctly

### **Notification System:**
- [ ] Student records created in Firestore
- [ ] Firebase Function runs every 2 minutes
- [ ] ETAs checked against `notificationPreferenceByTime`
- [ ] FCM notifications sent to parents
- [ ] `notified` flag updated to prevent duplicates

### **Duplicate Prevention:**
- [ ] `lastNotifiedETAs` map prevents duplicate notifications
- [ ] 2-minute threshold working
- [ ] ETA recalculation doesn't trigger duplicate notifications

### **GPS Sources:**
- [ ] Driver phone GPS updates Firestore
- [ ] Hardware GPS (if implemented) updates Firestore
- [ ] Both sources trigger Ola Maps API calls
- [ ] Both sources update ETAs correctly

---

## 🐛 Common Issues & Fixes

### **Issue: CORS Error in Web**

**Error:**
```
Access to fetch at 'https://api.olamaps.io' from origin 'http://localhost' 
has been blocked by CORS policy
```

**Fix:**
1. Deploy Cloud Function: `firebase deploy --only functions:olaDistanceMatrix`
2. Update `_cloudFunctionUrl` in code
3. Set `_useCloudFunctionProxy = true`

---

### **Issue: 401 Unauthorized**

**Error:**
```
API Authentication Error: Invalid API key
```

**Fix:**
1. Check API key in `ola_distance_matrix_service.dart`
2. Verify at https://maps.olakrutrim.com/
3. Ensure key has Distance Matrix API enabled

---

### **Issue: No Notifications Sent**

**Check:**
1. Firebase Functions deployed: `firebase deploy --only functions`
2. Student has `fcmToken` and `notified: false`
3. Bus is `isActive: true` in `bus_status`
4. ETA is <= `notificationPreferenceByTime`
5. Check Function logs: `firebase functions:log`

---

### **Issue: Mobile App Not Calling API**

**Check:**
1. `_useMockData = false` in `busmate_app`
2. Internet connection on phone
3. GPS permissions granted
4. Background location enabled
5. Check logs: `flutter logs`

---

## ✅ Success Criteria

**System is working correctly when:**

1. **Web Admin:**
   - Bus simulator shows real ETAs from Ola Maps
   - Console shows "Real Ola Maps API working via Cloud Function"
   - No CORS errors

2. **Mobile App:**
   - Logs show "Received ETAs from API"
   - Firestore `bus_status` updates every 2-30 seconds
   - Segment completion triggers recalculation

3. **Notifications:**
   - Parents receive FCM notifications
   - `notified` flag updates in Firestore
   - No duplicate notifications sent

4. **Cost:**
   - Cloud Function invocations < 2M/month (FREE tier)
   - Ola Maps API calls reasonable (~5-7 per route)

---

## 📈 Next Steps After Testing

Once everything works:

1. **Remove Mock Data:**
   - Ensure `_useMockData = false` in both apps
   - Ensure `_useCloudFunctionProxy = true` in web

2. **Monitor Costs:**
   - Check Firebase Functions usage
   - Check Ola Maps API quota
   - Set billing alerts

3. **Add Error Handling:**
   - Fallback to straight-line distance if API fails
   - Retry logic for failed API calls
   - User-friendly error messages

4. **Optimize:**
   - Adjust segment count for different route lengths
   - Fine-tune notification timing
   - Add caching for frequently requested routes

---

## 🎉 Ready to Test!

**Recommended Testing Order:**

1. ✅ **Start with Quick API Test** (2 minutes)
   - Verify API key works
   
2. ✅ **Web Admin Simulator** (5 minutes)
   - Test Cloud Function proxy
   - See real ETAs in browser
   
3. ✅ **Mobile App** (30 minutes)
   - Test real GPS tracking
   - Verify segment completion
   
4. ✅ **End-to-End Notifications** (1 hour)
   - Complete production flow
   - Verify student notifications

**Good luck! 🚀**
