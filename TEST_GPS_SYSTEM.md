# 🧪 Test Unified GPS System

## ✅ Deployment Status

**Firebase Function:** `onBusLocationUpdate` - **ACTIVE** ✅
- Region: us-central1
- Memory: 256MB
- Timeout: 60 seconds
- Trigger: Realtime Database `bus_locations/{schoolId}/{busId}`

---

## 🎯 Testing Options

### **Option 1: Test with Mobile App (Recommended)**

1. **Run the app:**
```powershell
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"
flutter run
```

2. **Login as driver and start route**

3. **Monitor in Firebase Console:**
   - **Realtime Database** → `bus_locations/{schoolId}/{busId}` 
     - Should update every 2 seconds with GPS data
   
   - **Firestore** → `bus_status/{busId}` → `remainingStops`
     - Should update ETAs every 30 seconds
   
   - **Functions** → Logs
     - Should see: "📍 GPS Update: Bus..." messages

4. **Watch terminal logs:**
```powershell
flutter logs
```

Look for:
```
📍 [BackgroundLocator] GPS sent to Realtime Database
✅ [BackgroundLocator] Firestore updated successfully
```

---

### **Option 2: Manual Test (No App Needed)**

**Manually add GPS data to Realtime Database:**

1. Open Firebase Console: https://console.firebase.google.com/project/busmate-b80e8/database/data

2. Navigate to Realtime Database

3. Create a test path: `bus_locations/TEST_SCHOOL/TEST_BUS`

4. Add this JSON data:
```json
{
  "latitude": 13.0827,
  "longitude": 80.2707,
  "speed": 25.5,
  "accuracy": 10,
  "altitude": 50,
  "heading": 180,
  "timestamp": 1701234567890,
  "source": "test"
}
```

5. **Watch Function Logs:**
```powershell
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"
firebase functions:log --only onBusLocationUpdate --lines 20
```

**Expected Output:**
```
📍 GPS Update: Bus TEST_BUS from test
   Location: (13.0827, 80.2707), Speed: 25.5 m/s
⏭️ Skipping ETA recalculation (or)
🚀 Triggering ETA recalculation for bus TEST_BUS
```

---

### **Option 3: Create Test Bus Status (For Full ETA Test)**

**To test Ola Maps API calls, you need a bus with active status:**

1. **Firestore Console** → `bus_status` collection → Add document

Document ID: `TEST_BUS`

```json
{
  "isActive": true,
  "latitude": 13.0827,
  "longitude": 80.2707,
  "currentSpeed": 0,
  "busNo": "TEST-123",
  "schoolId": "TEST_SCHOOL",
  "remainingStops": [
    {
      "name": "Stop 1",
      "latitude": 13.0878,
      "longitude": 80.2785,
      "estimatedMinutesOfArrival": null,
      "distanceMeters": null
    },
    {
      "name": "Stop 2",
      "latitude": 13.0412,
      "longitude": 80.2565,
      "estimatedMinutesOfArrival": null,
      "distanceMeters": null
    }
  ],
  "lastETACalculation": null,
  "lastUpdated": null
}
```

2. **Add GPS to Realtime Database:**
   - Path: `bus_locations/TEST_SCHOOL/TEST_BUS`
   - Data: Same as Option 2

3. **Watch Function Logs:**
```powershell
firebase functions:log --only onBusLocationUpdate --lines 30
```

**Expected Output:**
```
📍 GPS Update: Bus TEST_BUS from test
   Location: (13.0827, 80.2707), Speed: 25.5 m/s
🚀 Triggering ETA recalculation for bus TEST_BUS
📡 Calling Ola Maps API for 2 stops...
   📍 Stop 1: 3 min (1.8 km)
   📍 Stop 2: 8 min (4.2 km)
✅ Updated 2 stop ETAs for bus TEST_BUS
```

4. **Verify in Firestore:**
   - Go to: `bus_status/TEST_BUS/remainingStops`
   - Check: `estimatedMinutesOfArrival` and `distanceMeters` are now populated!

---

## 📊 What to Verify

### **1. GPS Flow:**
- [ ] Mobile app sends GPS to Realtime Database every 2 seconds
- [ ] Realtime Database shows live updates at `bus_locations/{schoolId}/{busId}`
- [ ] No Ola Maps API calls from mobile app (check app logs)

### **2. Function Triggers:**
- [ ] Function logs show GPS updates being received
- [ ] Function only recalculates ETAs every 30 seconds (not every 2 seconds)
- [ ] Function recalculates when bus is near stop (<200m)

### **3. Ola Maps API:**
- [ ] Function calls Ola Maps API successfully
- [ ] API returns valid ETAs
- [ ] ETAs include traffic data (`duration_in_traffic`)

### **4. Firestore Updates:**
- [ ] `bus_status/{busId}` latitude/longitude updates
- [ ] `remainingStops` array has updated ETAs
- [ ] `lastETACalculation` timestamp updates

### **5. Parent App:**
- [ ] Parents see updated ETAs in real-time
- [ ] Notifications still work
- [ ] ETAs are accurate

---

## 🐛 Troubleshooting

### **Problem: Function not triggering**

**Check:**
```powershell
# Verify function is deployed
firebase functions:list

# Check Realtime Database rules
# Make sure writes are allowed
```

**Fix:** Ensure Realtime Database rules allow writes:
```json
{
  "rules": {
    "bus_locations": {
      "$schoolId": {
        "$busId": {
          ".write": true,
          ".read": true
        }
      }
    }
  }
}
```

---

### **Problem: No ETAs calculated**

**Check Function Logs:**
```powershell
firebase functions:log --only onBusLocationUpdate
```

**Common Issues:**
1. `bus_status` document doesn't exist → Create it in Firestore
2. `isActive: false` → Set to `true`
3. `remainingStops` is empty → Add stops
4. API key invalid → Check Ola Maps dashboard

---

### **Problem: Too many API calls**

**Expected Behavior:**
- GPS updates: Every 2 seconds ✅
- API calls: Every 30 seconds ONLY ✅

**Check Logs:**
```powershell
firebase functions:log --only onBusLocationUpdate --lines 50
```

Look for: "⏭️ Skipping ETA recalculation" - This is good!
Only see "🚀 Triggering ETA recalculation" once every 30 seconds.

---

## 📈 Monitor Costs

**Firebase Console → Usage:**
- Realtime Database: Should be FREE (well within 1GB limit)
- Cloud Functions: Should be FREE (under 2M invocations/month)
- Firestore: Minimal writes (only GPS coordinates, not full status)

**Ola Maps Dashboard:**
- Check API usage: ~2 calls/minute per active bus
- 50 buses × 2 calls/min × 60 min = 6,000 calls/hour
- Daily: ~50,000 calls (if running 8 hours)

---

## ✅ Success Criteria

**System is working when:**

1. **Mobile App:**
   - ✅ Sends GPS every 2 seconds
   - ✅ No "Calling Ola Maps API" in app logs
   - ✅ Battery life improved

2. **Realtime Database:**
   - ✅ Shows live GPS updates
   - ✅ Source field shows "phone" or "hardware"

3. **Firebase Function:**
   - ✅ Triggers on GPS updates
   - ✅ Logs show "📍 GPS Update..." messages
   - ✅ Calls Ola Maps API every 30 seconds
   - ✅ Updates Firestore successfully

4. **Firestore:**
   - ✅ `bus_status` has current GPS coordinates
   - ✅ `remainingStops` has updated ETAs
   - ✅ `lastETACalculation` timestamp is recent

5. **Parents:**
   - ✅ See real-time GPS on map
   - ✅ See updated ETAs
   - ✅ Receive notifications on time

---

## 🎉 Next Steps

Once testing is successful:

1. **Remove test data** from Realtime Database and Firestore
2. **Test with real bus route** using mobile app
3. **Monitor costs** for first few days
4. **Adjust timing** if needed (30 seconds can be changed)
5. **Deploy to production** 🚀

---

## 📞 Quick Commands

```powershell
# View function logs
firebase functions:log --only onBusLocationUpdate

# View all logs
firebase functions:log

# Redeploy if needed
firebase deploy --only functions:onBusLocationUpdate

# Run mobile app
cd busmate_app
flutter run

# Check app logs
flutter logs
```

Good luck! 🎯
