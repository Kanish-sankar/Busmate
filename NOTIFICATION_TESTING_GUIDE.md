# 🧪 Notification System Testing Guide

## ✅ Pre-Deployment Verification Complete

### 1. Cloud Functions Deployed ✅
Both critical functions are active and deployed:
- ✅ **sendBusArrivalNotifications** - Scheduled every 2 minutes
- ✅ **resetStudentNotifiedStatus** - Scheduled every 15 minutes (`*/15 * * * *`)
- ✅ **onBusLocationUpdate** - Triggered on Realtime DB updates

### 2. Voice Files Present ✅
Tamil voice file confirmed in both platforms:
- ✅ `android/app/src/main/res/raw/notification_tamil.wav`
- ✅ `ios/Runner/notification_tamil.wav`

### 3. Code Configuration ✅
Both app and Cloud Functions configured to use Tamil voice:
- ✅ `notification_helper.dart` - Returns "notification_tamil" for all languages
- ✅ `functions/index.js` - Returns "notification_tamil" for all languages

---

## 🎯 Complete Testing Checklist

### Test 1: Student Data Configuration

**What to Check:**
1. Open Firebase Console → Firestore Database
2. Navigate to `students` collection
3. Select any test student document
4. Verify these fields exist and are configured correctly:

**Required Fields:**
```javascript
{
  studentId: "S12345", // Should be document ID
  name: "Test Student",
  schoolId: "SCHOOL_ID", // Must exist
  assignedBusId: "BUS_ID", // Must match a bus in Realtime DB
  stopLocation: "Stop Name", // Must match exactly with route stop name
  
  // CRITICAL for notifications:
  fcmToken: "eXyZ...abc123", // Must be present and valid
  notified: false, // Should be false to receive notification
  notificationType: "Voice Notification", // CASE SENSITIVE
  languagePreference: "tamil", // Can be any language (all use Tamil now)
  notificationPreferenceByTime: 10 // Minutes - will notify when ETA <= this
}
```

**How to Fix Missing Fields:**
- If `fcmToken` is missing → Student needs to log in to the app on a device
- If `notificationType` is missing → Add manually or set in student settings
- If `languagePreference` is missing → Add manually (e.g., "tamil", "english")
- If `notified` is true → Change to false OR wait for trip schedule reset

---

### Test 2: Bus Configuration in Realtime Database

**What to Check:**
1. Open Firebase Console → Realtime Database
2. Navigate to `bus_locations/{schoolId}/{busId}`
3. Verify structure:

**Required Structure:**
```javascript
{
  "bus_locations": {
    "SCHOOL_ID": {
      "BUS_ID": {
        isActive: true, // Must be true
        activeRouteId: "ROUTE123", // Must match route in Firestore
        tripDirection: "pickup", // or "drop"
        currentLocation: {
          latitude: 12.9716,
          longitude: 77.5946
        },
        lastUpdated: "2025-12-03T12:30:00Z",
        driverName: "Driver Name",
        driverId: "DRV001",
        
        // CRITICAL - Updated by onBusLocationUpdate:
        remainingStops: [
          {
            name: "Stop Name", // Must match student.stopLocation
            estimatedMinutesOfArrival: 8.5, // In minutes
            estimatedTimeOfArrival: {
              _seconds: 1733231400,
              _nanoseconds: 0
            }
          },
          // ... more stops
        ],
        
        // Optional - for duplicate prevention:
        lastNotifiedETAs: {
          "Stop Name": {
            _seconds: 1733230800,
            _nanoseconds: 0
          }
        }
      }
    }
  }
}
```

**How to Trigger Update:**
- Start GPS simulation in app
- Or manually update `currentLocation` in Realtime DB
- `onBusLocationUpdate` will calculate ETAs automatically

---

### Test 3: Route Schedule Configuration

**What to Check:**
1. Open Firebase Console → Firestore Database
2. Navigate to `schools/{schoolId}/route_schedules`
3. Create or verify route schedule document:

**Required Structure:**
```javascript
{
  routeId: "ROUTE123", // Should be document ID
  routeName: "Route A - Morning Pickup",
  startTime: "07:00", // HH:MM format - when trip starts
  endTime: "09:00", // HH:MM format
  daysOfWeek: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
  direction: "pickup", // or "drop"
  stops: [
    { name: "Stop 1", order: 1 },
    { name: "Stop 2", order: 2 }
  ]
}
```

**How Reset Works:**
- Every 15 minutes, `resetStudentNotifiedStatus` checks all schedules
- If current time is within ±15 minutes of `startTime` AND it's a scheduled day
- Students on that bus with `lastNotifiedRoute != direction` get reset to `notified=false`

---

### Test 4: End-to-End Notification Flow

**Step-by-Step Test:**

#### Step 1: Setup (5 minutes)
```bash
1. Configure student in Firestore:
   - notified = false
   - fcmToken = (valid token from device)
   - notificationType = "Voice Notification"
   - notificationPreferenceByTime = 10 (minutes)
   - stopLocation = "Test Stop"

2. Configure bus in Realtime DB:
   - isActive = true
   - Add "Test Stop" to remainingStops
   - Set estimatedMinutesOfArrival = 15 (higher than preference)

3. Install app on test device and login as this student
```

#### Step 2: Trigger Notification (Wait 2 minutes)
```bash
1. In Realtime DB, update bus location:
   bus_locations/{schoolId}/{busId}/remainingStops/0/estimatedMinutesOfArrival = 8

2. Wait for next scheduled run of sendBusArrivalNotifications (every 2 minutes)
   - Check time: XX:00, XX:02, XX:04, XX:06, etc.

3. Within 2 minutes, you should:
   - See notification on device
   - Hear Tamil voice notification
   - See in Firestore: student.notified = true
```

#### Step 3: Verify Logs
```bash
# Check Cloud Function logs
firebase functions:log --only sendBusArrivalNotifications

# Look for these messages:
- "📋 Processing X students for notifications"
- "🚍 Queuing notification for [student name] (ETA: Xmin)"
- "📤 Sending X notifications in batch"
- "✅ Successfully sent X notifications"
- "💾 Performing X database updates"
```

#### Step 4: Test Duplicate Prevention
```bash
1. Update ETA to 7.5 minutes (change < 2 min)
2. Wait 2 minutes
3. Should see: "⏭️ Skipping notification - already notified"
4. No notification sent

5. Update ETA to 5 minutes (change ≥ 2 min)
6. Wait 2 minutes
7. Should see: "🔔 ETA changed by X min - allowing notification"
8. New notification sent
```

#### Step 5: Test Trip Reset
```bash
1. Set route schedule startTime to 15 minutes from now
2. Ensure student.notified = true
3. Ensure student.lastNotifiedRoute = "drop"
4. Set bus.tripDirection = "pickup" (different direction)
5. Wait until startTime ± 15 minutes window
6. Check logs:
   firebase functions:log --only resetStudentNotifiedStatus
   
7. Should see:
   - "🚀 Trip starting for bus [busId] (pickup - [route name])"
   - "✅ Resetting notification for [student name]"
   - "✅ Reset X student notifications for trip start"

8. Verify in Firestore:
   - student.notified = false
   - student.lastNotifiedRoute = null
```

---

## 🐛 Troubleshooting Guide

### Issue: No Notification Received

**Check 1: Student Configuration**
```javascript
// In Firestore students collection
notified: false ❌ Must be false
fcmToken: "..." ✅ Must exist and be valid
notificationType: "Voice Notification" ✅ Case-sensitive
notificationPreferenceByTime: 10 ✅ Must be a number
```

**Check 2: Bus Status**
```javascript
// In Realtime Database
isActive: true ✅ Must be true
remainingStops: [...] ✅ Must contain student's stop
estimatedMinutesOfArrival: 8 ✅ Must be ≤ student preference
```

**Check 3: Cloud Function Execution**
```bash
# View logs
firebase functions:log --only sendBusArrivalNotifications

# Common errors:
- "No students to process" → All students have notified=true
- "Bus is not active" → Set isActive=true in Realtime DB
- "No ETA data for student" → Stop name doesn't match exactly
```

---

### Issue: Voice Not Playing

**Check 1: Notification Type**
```javascript
// Must be EXACTLY this (case-sensitive)
notificationType: "Voice Notification"

// NOT:
// "voice notification" ❌
// "Voice notification" ❌
// "Voice" ❌
```

**Check 2: File Exists**
```bash
# Android
android/app/src/main/res/raw/notification_tamil.wav ✅

# iOS
ios/Runner/notification_tamil.wav ✅
```

**Check 3: Android Channel**
- App must call `NotificationHelper.initialize()` in main()
- Channel "busmate" must be created with sound
- Check app has notification permissions

**Check 4: iOS Sound**
- File must be .wav format
- Must be in Runner folder
- Must have `.wav` extension in payload

---

### Issue: Duplicate Notifications

**Check:** Last Notified ETAs
```javascript
// In Realtime Database
bus_locations/{schoolId}/{busId}/lastNotifiedETAs

// Should contain:
{
  "Stop Name": { _seconds: 1733230800 }
}
```

**Expected Behavior:**
- Won't notify if ETA changed < 2 minutes
- Will notify if ETA changed ≥ 2 minutes
- Will notify if `lastNotifiedETAs` is empty/missing

---

### Issue: Reset Not Working

**Check 1: Schedule Time Window**
```javascript
// Route schedule
startTime: "07:00"

// Current time must be within ±15 minutes:
// Will reset between 06:45 - 07:15
```

**Check 2: Day of Week**
```javascript
// Must match exactly (case-sensitive)
daysOfWeek: ["Monday", "Tuesday", ...]

// NOT:
// "monday" ❌
// "Mon" ❌
```

**Check 3: Direction Mismatch**
```javascript
// Reset only happens if:
student.lastNotifiedRoute !== bus.tripDirection

// Example - WILL reset:
student.lastNotifiedRoute: "drop"
bus.tripDirection: "pickup" ✅

// Example - WON'T reset:
student.lastNotifiedRoute: "pickup"
bus.tripDirection: "pickup" ❌
```

---

## 📊 Success Criteria

### ✅ System is Working Correctly When:

1. **Notifications Send Properly:**
   - Student receives notification when ETA ≤ preference
   - Tamil voice plays automatically
   - `notified` changes to `true` in Firestore
   - `lastNotifiedRoute` set to current trip direction

2. **Duplicate Prevention Works:**
   - No second notification if ETA changed < 2 minutes
   - New notification if ETA changed ≥ 2 minutes
   - Logs show "Skipping notification - already notified"

3. **Trip Reset Functions:**
   - At trip start time (±15 min), students reset to `notified=false`
   - Only resets if direction changed (pickup vs drop)
   - Logs show "Trip starting" and "Resetting notification"

4. **Voice Notifications Play:**
   - Tamil voice file plays on notification
   - Works for all language preferences (all use Tamil temporarily)
   - Sound channel configured correctly on Android
   - .wav file plays on iOS

---

## 🚀 Quick Test Command

Run this to monitor notifications in real-time:

```bash
# Terminal 1: Watch notification function logs
firebase functions:log --only sendBusArrivalNotifications

# Terminal 2: Watch reset function logs
firebase functions:log --only resetStudentNotifiedStatus

# Terminal 3: Watch bus location updates
firebase functions:log --only onBusLocationUpdate
```

---

## 📞 Expected Output (Success)

### sendBusArrivalNotifications (Every 2 minutes):
```
🚀 Starting notification batch job at 2025-12-03T12:30:00
📋 Processing 5 students for notifications
🚍 Queuing notification for John Doe (ETA: 8min)
🚍 Queuing notification for Jane Smith (ETA: 10min)
📤 Sending 2 notifications in batch
✅ Successfully sent 2 notifications
💾 Performing 2 database updates in batch
✅ Successfully updated 2 documents
⏱️ Notification job completed in 1234ms
```

### resetStudentNotifiedStatus (Every 15 minutes):
```
🔄 Checking trip schedules for notification resets...
🚀 Trip starting for bus BUS123 (pickup - Route A)
   ✅ Resetting notification for John Doe
   ✅ Resetting notification for Jane Smith
✅ Reset 2 student notifications for trip start
```

### No Trips Starting:
```
🔄 Checking trip schedules for notification resets...
📋 No trips starting now - no resets needed
```

---

**Last Updated**: December 3, 2025  
**Status**: Ready for Testing  
**All Components**: Deployed and Verified ✅
