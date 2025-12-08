# 🕐 Dynamic Time-Based Route & Notification Management System

## 📋 System Overview

A comprehensive **admin-configured** time-controlled system that:
1. **Activates routes only during admin-defined time windows** (from `route_schedules`)
2. **Resets notification status at trip start time**
3. **Prevents GPS processing & notifications outside trip hours**
4. **Automatically switches between pickup and drop routes based on schedule**
5. **Ensures all students get notifications or force-true at trip end**
6. **100% Dynamic - No hardcoded times!**

---

## 🎯 Core Requirements

### ⏰ Dynamic Time-Based Route Activation
- ✅ GPS updates **ONLY processed during route's `startTime` to `endTime`**
- ✅ Times come from `route_schedules` collection (admin-editable)
- ✅ Example: Route 1 (7:00-9:00), Route 2 (15:00-17:00), Route 3 (13:30-14:30)
- ✅ Outside scheduled times: **No GPS processing, no ETA calculation, no notifications**

### 🔄 Dynamic Notification Reset Logic
- ✅ At route `startTime`: All students on that bus → `notified: false`
- ✅ During trip: When student gets notification → `notified: true` (permanent for this trip)
- ✅ At route `endTime`: All students still `false` → Force `notified: true`
- ✅ Next trip starts: Reset to `false` again

**Example Timeline:**
```
Route Schedule: startTime: "07:00", endTime: "09:00"

06:59 → All students: notified = true (from previous day)
07:00 → 🔄 RESET: All students: notified = false
07:15 → Student A gets notification → notified = true
07:30 → Student B gets notification → notified = true
08:45 → Student C still false (bus didn't reach their stop yet)
09:00 → 🔒 FORCE: Student C → notified = true (trip ended)
09:01 → No more notifications possible until next trip
```

### 📍 Route Direction Auto-Detection
- ✅ System reads `direction` field from active `route_schedule`
- ✅ `direction: "pickup"` → Bus going from first stop to last stop
- ✅ `direction: "drop"` → Bus going from last stop to first stop
- ✅ RTDB gets `tripDirection` field updated automatically

---

## 🏗️ Architecture Components

### 1. **Route Schedules Collection** (Firestore - Admin Managed)
```
schools/{schoolId}/route_schedules/{scheduleId}
{
  busId: "0xSv1qGo9nzwwpKjnvpZ",
  routeName: "Morning Pickup Route",
  direction: "pickup",  // or "drop"
  startTime: "07:00",   // ⚠️ ADMIN CONFIGURABLE
  endTime: "09:00",     // ⚠️ ADMIN CONFIGURABLE
  daysOfWeek: [1, 2, 3, 4, 5],  // Monday-Friday
  stops: [...],
  isActive: true,
  
  // ⚠️ Notification windows = startTime & endTime
  // No need for separate fields - use existing times
}
```

### 2. **Trip State Tracking** (RTDB)
```
bus_locations/{schoolId}/{busId}
{
  isActive: true,
  activeRouteId: "wU0QBJOWB1J8nDwkSi1p",
  tripDirection: "pickup",
  
  // NEW FIELDS - Copied from active route_schedule
  tripStartTime: "07:00",    // From route_schedule.startTime
  tripEndTime: "09:00",      // From route_schedule.endTime
  isWithinTripWindow: true,  // Calculated: currentTime >= tripStartTime && currentTime <= tripEndTime
  lastWindowCheck: timestamp
}
```

### 3. **Student Notification State** (Firestore)
```
students/{studentId}
{
  notified: false,  // Reset at trip start, set to true after notification
  lastNotifiedRoute: "pickup",  // Track which direction (pickup/drop)
  lastNotifiedAt: timestamp,
  currentTripId: "scheduleId_2024-12-09",  // Unique per trip
  notificationHistory: {
    "2024-12-09_morning": {
      notified: true,
      notifiedAt: timestamp,
      eta: 10
    },
    "2024-12-09_evening": {
      notified: true,
      notifiedAt: timestamp,
      eta: 8
    }
  }
}
```

---

## 🔄 Workflow Diagrams

### **Morning Pickup Flow (7:00 AM - 9:00 AM)**

```
06:55 AM  ┌─────────────────────────────────┐
          │ System Check: 5 min before trip  │
          │ No action yet                    │
          └─────────────────────────────────┘
                       ↓
07:00 AM  ┌─────────────────────────────────┐
          │ TRIP START TRIGGER               │
          │ • Reset ALL students: notified=false│
          │ • Set currentTripId              │
          │ • Activate route schedule        │
          └─────────────────────────────────┘
                       ↓
07:05 AM  ┌─────────────────────────────────┐
          │ GPS Update from Driver App       │
          │ • Check if within time window ✓  │
          │ • Process ETA calculation        │
          │ • Check student preferences      │
          └─────────────────────────────────┘
                       ↓
07:10 AM  ┌─────────────────────────────────┐
          │ Student A: ETA=10min, Pref=10min │
          │ • Send notification              │
          │ • Set notified=true              │
          └─────────────────────────────────┘
                       ↓
07:30 AM  ┌─────────────────────────────────┐
          │ Student B: ETA=8min, Pref=10min  │
          │ • Send notification              │
          │ • Set notified=true              │
          └─────────────────────────────────┘
                       ↓
09:00 AM  ┌─────────────────────────────────┐
          │ TRIP END TRIGGER                 │
          │ • Force ALL students: notified=true│
          │ • Students who didn't get notification│
          │   due to timing still set to true │
          │ • Deactivate route               │
          └─────────────────────────────────┘
                       ↓
10:00 AM  ┌─────────────────────────────────┐
          │ GPS Update (Outside Window)      │
          │ • Skip processing ✗              │
          │ • No ETA calculation             │
          │ • No notifications               │
          └─────────────────────────────────┘
```

### **Evening Drop Flow (5:00 PM - 7:00 PM)**

```
04:55 PM  ┌─────────────────────────────────┐
          │ System Check: 5 min before trip  │
          │ No action yet                    │
          └─────────────────────────────────┘
                       ↓
05:00 PM  ┌─────────────────────────────────┐
          │ TRIP START TRIGGER               │
          │ • Reset ALL students: notified=false│
          │ • Set new currentTripId          │
          │ • Activate DROP route            │
          └─────────────────────────────────┘
                       ↓
05:15 PM  ┌─────────────────────────────────┐
          │ GPS Processing Active            │
          │ • Same notification logic        │
          │ • Different route (drop)         │
          └─────────────────────────────────┘
                       ↓
07:00 PM  ┌─────────────────────────────────┐
          │ TRIP END TRIGGER                 │
          │ • Force ALL students: notified=true│
          │ • Deactivate route               │
          └─────────────────────────────────┘
```

---

## 💾 Database Schema Updates

### Firestore Collections

#### **route_schedules** (Enhanced)
```javascript
{
  busId: string,
  routeName: string,
  direction: "pickup" | "drop",
  startTime: "HH:MM",
  endTime: "HH:MM",
  daysOfWeek: number[],  // 1-7 (Monday-Sunday)
  stops: array,
  
  // Notification timing controls
  notificationWindow: {
    resetBeforeMinutes: 0,        // Minutes before startTime to reset (default: 0 = at startTime)
    forceCompleteAfterEnd: true,  // Force notified=true at endTime
  },
  
  // Auto-activation
  autoActivate: true,  // Enable time-based activation
  
  isActive: true,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### **students** (Enhanced)
```javascript
{
  // Existing fields...
  assignedBusId: string,
  notificationPreferenceByTime: number,
  fcmToken: string,
  stopping: string,
  
  // Enhanced notification tracking
  notified: false,  // Current trip notification status
  lastNotifiedRoute: "pickup" | "drop" | null,
  lastNotifiedAt: timestamp | null,
  currentTripId: string | null,  // Format: "scheduleId_YYYY-MM-DD"
  
  // Notification history (optional - for analytics)
  notificationHistory: {
    "YYYY-MM-DD_morning": {
      notified: boolean,
      notifiedAt: timestamp,
      eta: number,
      routeId: string
    }
  }
}
```

### Realtime Database Structure

#### **bus_locations/{schoolId}/{busId}**
```javascript
{
  // Existing fields...
  latitude: number,
  longitude: number,
  isActive: boolean,
  
  // Enhanced trip tracking
  activeRouteId: string,
  tripDirection: "pickup" | "drop",
  
  currentTripWindow: {
    scheduleId: string,
    startTime: "HH:MM",
    endTime: "HH:MM",
    isWithinWindow: boolean,
    tripDate: "YYYY-MM-DD",
    resetCompletedAt: timestamp | null,
    forceCompleteScheduledFor: timestamp
  },
  
  remainingStops: array,
  lastETACalculation: timestamp
}
```

---

## 🔧 Implementation Plan

### **Phase 1: Cloud Functions Updates**

#### 1.1 Enhanced GPS Processing with Time Window Check
```javascript
// File: functions/index.js

exports.onBusLocationUpdate = onValueWritten(
  { ref: "/bus_locations/{schoolId}/{busId}" },
  async (event) => {
    const schoolId = event.params.schoolId;
    const busId = event.params.busId;
    const gpsData = event.data.after.val();
    
    // STEP 1: Check if within valid trip window
    const tripWindow = gpsData.currentTripWindow;
    if (!tripWindow || !tripWindow.isWithinWindow) {
      console.log(`⏹️ Outside trip window - skipping GPS processing`);
      return;
    }
    
    // STEP 2: Verify current time is within schedule
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    
    if (currentTime < tripWindow.startTime || currentTime > tripWindow.endTime) {
      console.log(`⏹️ Current time ${currentTime} outside window ${tripWindow.startTime}-${tripWindow.endTime}`);
      await admin.database().ref(`bus_locations/${schoolId}/${busId}/currentTripWindow`).update({
        isWithinWindow: false
      });
      return;
    }
    
    // STEP 3: Continue with normal GPS processing
    // ... existing ETA calculation logic
  }
);
```

#### 1.2 Trip Start/End Scheduler
```javascript
// NEW FUNCTION: Monitor and trigger trip events
exports.manageTripTimeWindows = onSchedule("*/5 * * * *", async (event) => {
  const db = admin.firestore();
  const rtdb = admin.database();
  
  const now = new Date();
  const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  const currentDay = now.getDay() || 7;
  const currentDate = now.toISOString().split('T')[0];
  
  console.log(`🕐 Trip Window Manager: ${currentTime} on ${currentDay}`);
  
  // Get all active route schedules
  const schedulesSnapshot = await db.collectionGroup('route_schedules')
    .where('isActive', '==', true)
    .where('autoActivate', '==', true)
    .get();
  
  for (const scheduleDoc of schedulesSnapshot.docs) {
    const schedule = scheduleDoc.data();
    const scheduleId = scheduleDoc.id;
    const schoolId = scheduleDoc.ref.parent.parent.id;
    
    // Check if today is a scheduled day
    if (!schedule.daysOfWeek || !schedule.daysOfWeek.includes(currentDay)) {
      continue;
    }
    
    // Calculate time differences
    const timeDiffStart = calculateTimeDifference(currentTime, schedule.startTime);
    const timeDiffEnd = calculateTimeDifference(currentTime, schedule.endTime);
    
    // TRIP START TRIGGER (at startTime)
    if (timeDiffStart >= 0 && timeDiffStart <= 5) {
      await handleTripStart(schoolId, schedule.busId, scheduleId, schedule, currentDate);
    }
    
    // TRIP END TRIGGER (at endTime)
    if (timeDiffEnd >= 0 && timeDiffEnd <= 5) {
      await handleTripEnd(schoolId, schedule.busId, scheduleId, schedule, currentDate);
    }
  }
});
```

#### 1.3 Trip Start Handler
```javascript
async function handleTripStart(schoolId, busId, scheduleId, schedule, currentDate) {
  console.log(`🚀 TRIP START: ${schedule.routeName} (${schedule.direction})`);
  
  const tripId = `${scheduleId}_${currentDate}`;
  
  // STEP 1: Reset all students on this bus
  const studentsSnapshot = await admin.firestore()
    .collection('students')
    .where('assignedBusId', '==', busId)
    .where('schoolId', '==', schoolId)
    .get();
  
  if (!studentsSnapshot.empty) {
    const batch = admin.firestore().batch();
    let resetCount = 0;
    
    studentsSnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        notified: false,
        currentTripId: tripId,
        lastNotifiedRoute: null,
        lastNotifiedAt: null
      });
      resetCount++;
    });
    
    await batch.commit();
    console.log(`✅ Reset ${resetCount} students for trip ${tripId}`);
  }
  
  // STEP 2: Update RTDB with trip window
  await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
    activeRouteId: scheduleId,
    tripDirection: schedule.direction,
    currentTripWindow: {
      scheduleId: scheduleId,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      isWithinWindow: true,
      tripDate: currentDate,
      resetCompletedAt: admin.database.ServerValue.TIMESTAMP,
      forceCompleteScheduledFor: calculateFutureTimestamp(schedule.endTime)
    }
  });
  
  console.log(`✅ Trip window activated for bus ${busId}`);
}
```

#### 1.4 Trip End Handler
```javascript
async function handleTripEnd(schoolId, busId, scheduleId, schedule, currentDate) {
  console.log(`🏁 TRIP END: ${schedule.routeName} (${schedule.direction})`);
  
  // STEP 1: Force all students to notified=true
  const studentsSnapshot = await admin.firestore()
    .collection('students')
    .where('assignedBusId', '==', busId)
    .where('schoolId', '==', schoolId)
    .get();
  
  if (!studentsSnapshot.empty) {
    const batch = admin.firestore().batch();
    let forceCount = 0;
    
    studentsSnapshot.forEach((doc) => {
      const student = doc.data();
      
      // Only update if still false (students already notified stay true)
      if (student.notified === false) {
        batch.update(doc.ref, {
          notified: true,
          lastNotifiedRoute: schedule.direction
        });
        forceCount++;
      }
    });
    
    await batch.commit();
    console.log(`✅ Force-completed ${forceCount} students (${studentsSnapshot.size - forceCount} already notified)`);
  }
  
  // STEP 2: Deactivate trip window in RTDB
  await admin.database().ref(`bus_locations/${schoolId}/${busId}/currentTripWindow`).update({
    isWithinWindow: false
  });
  
  console.log(`✅ Trip window closed for bus ${busId}`);
}
```

### **Phase 2: Notification Logic Updates**

#### 2.1 Enhanced Notification Check
```javascript
// File: functions/index.js - sendBusArrivalNotifications

// Inside student loop
for (const student of students) {
  // CHECK 1: Is there an active trip?
  const tripWindow = busData.currentTripWindow;
  if (!tripWindow || !tripWindow.isWithinWindow) {
    console.log(`⏹️ No active trip for ${student.name} - skipping`);
    continue;
  }
  
  // CHECK 2: Is student already notified for THIS trip?
  if (student.notified === true && student.currentTripId === tripWindow.tripId) {
    console.log(`✓ ${student.name} already notified for current trip`);
    continue;
  }
  
  // CHECK 3: Calculate ETA and check preference
  const stopData = findStopData(busData, student.stopping);
  if (!stopData) continue;
  
  const eta = stopData.estimatedMinutesOfArrival;
  if (eta <= student.notificationPreferenceByTime) {
    // SEND NOTIFICATION
    await sendNotification(student, eta, busId);
    
    // UPDATE STUDENT
    await admin.firestore()
      .collection('students')
      .doc(student.studentId)
      .update({
        notified: true,
        lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotifiedRoute: tripWindow.direction
      });
  }
}
```

---

## 📊 Example Timeline

### Monday, December 9, 2025

| Time  | Event | Action |
|-------|-------|--------|
| 06:55 | Pre-check | System ready, no action |
| 07:00 | Morning trip starts | Reset all students → `notified: false` |
| 07:05 | GPS update | Process ETA, within window ✓ |
| 07:10 | Student A ETA=10min | Send notification, set `notified: true` |
| 07:30 | Student B ETA=8min | Send notification, set `notified: true` |
| 08:00 | Student C ETA=15min | No notification (pref=10min) |
| 09:00 | Morning trip ends | Force all → `notified: true` (including Student C) |
| 12:00 | GPS update | Skip processing (outside window) ✗ |
| 17:00 | Evening trip starts | Reset all → `notified: false` (new trip) |
| 17:20 | Student A ETA=10min | Send notification, set `notified: true` |
| 17:45 | Student D ETA=5min | Send notification, set `notified: true` |
| 19:00 | Evening trip ends | Force all → `notified: true` |

---

## 🎯 Key Benefits

1. **No Manual Intervention**: Routes activate/deactivate automatically
2. **No Missed Notifications**: Force-complete ensures all students marked
3. **Battery Efficient**: GPS only processed during active trips
4. **Cost Efficient**: No unnecessary API calls outside trip hours
5. **Multi-Trip Support**: Same bus can run pickup AND drop with proper resets
6. **Audit Trail**: History tracking for debugging and analytics

---

## 🔐 Safety Mechanisms

1. **Double Check Time Windows**: Both RTDB flag and time comparison
2. **Graceful Degradation**: If schedule missing, fall back to manual activation
3. **Idempotent Operations**: Multiple triggers won't cause duplicate notifications
4. **Firestore Batch Operations**: Atomic updates for consistency
5. **Error Logging**: Comprehensive logging for troubleshooting

---

## 📝 Migration Checklist

- [ ] Add `notificationWindow` to existing route schedules
- [ ] Add `autoActivate: true` to route schedules
- [ ] Update `students` collection with new fields
- [ ] Deploy updated Cloud Functions
- [ ] Test with one bus in staging
- [ ] Monitor logs for first trip
- [ ] Roll out to production buses
- [ ] Update driver app UI (optional: show trip status)
- [ ] Update admin dashboard (optional: show active trips)

---

## 🧪 Testing Scenarios

1. **Morning Pickup**
   - Trip starts at 07:00 → All students reset ✓
   - Notification sent at 07:15 → Student marked ✓
   - Trip ends at 09:00 → Remaining students forced ✓

2. **Evening Drop**
   - Trip starts at 17:00 → All students reset (including morning ones) ✓
   - Notification sent at 17:30 → Student marked ✓
   - Trip ends at 19:00 → Remaining students forced ✓

3. **Outside Window**
   - GPS update at 10:00 → Skipped ✗
   - GPS update at 14:00 → Skipped ✗

4. **Edge Cases**
   - Student turns off phone during trip → Forced true at end ✓
   - Bus breaks down → Students still forced true at end ✓
   - Late notification (after trip end) → Prevented ✗

---

This architecture provides a robust, scalable, and efficient system for time-based route and notification management!
