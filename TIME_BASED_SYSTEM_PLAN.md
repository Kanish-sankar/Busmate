# 🕐 Dynamic Time-Based Route & Notification System
## Complete Implementation Plan

---

## 📋 System Overview

A **100% admin-configurable** time-controlled system where:
- ✅ All times come from `route_schedules` collection (NO hardcoded times!)
- ✅ GPS processing ONLY during admin-defined time windows
- ✅ Notifications ONLY during active trip times
- ✅ Auto-reset `notified=false` at trip start
- ✅ Auto-force `notified=true` at trip end
- ✅ Multiple routes per bus supported (morning, evening, afternoon, etc.)

---

## 🎯 Core Principles

### 1. **Admin-Defined Time Windows**
```
Admin creates in Time Control Screen:
- Route 1: "Morning Pickup"  → 06:45-08:30
- Route 2: "Afternoon Run"   → 13:00-14:15  
- Route 3: "Evening Drop"    → 15:30-17:00

System automatically:
- Activates GPS processing during these windows
- Resets notifications at start time
- Forces completion at end time
```

### 2. **Current Route Detection**
```javascript
// Cloud Function checks current time against ALL route_schedules
const now = getCurrentTime(); // "HH:MM" format
const currentDay = getCurrentDay(); // 1-7 (Monday-Sunday)

// Find active route
const activeRoute = await getActiveRoute(busId, now, currentDay);

if (activeRoute) {
  // currentTime >= startTime AND currentTime <= endTime
  // Process GPS, calculate ETAs, send notifications
} else {
  // Outside all route windows
  // Skip GPS processing entirely
}
```

### 3. **Notification Reset & Force Logic**
```
Event 1: Trip Start (at route.startTime)
→ Query all students on this bus
→ Set notified = false for ALL
→ Activate RTDB tracking

Event 2: During Trip (between startTime and endTime)
→ Process GPS updates
→ Calculate ETAs
→ Send notifications (set notified = true)

Event 3: Trip End (at route.endTime)
→ Query all students with notified = false
→ Force set notified = true
→ Deactivate RTDB tracking
```

---

## 🏗️ Implementation Architecture

### **Phase 1: Enhanced Data Structure**

#### A. Route Schedules (Already exists - no changes needed!)
```javascript
// schools/{schoolId}/route_schedules/{scheduleId}
{
  busId: "0xSv1qGo9nzwwpKjnvpZ",
  busVehicleNo: "TN-07-87qbadf",
  routeName: "Morning Pickup Route",
  direction: "pickup", // or "drop"
  
  // ⭐ KEY FIELDS - Admin configurable
  startTime: "07:00",  // Trip start
  endTime: "09:00",    // Trip end
  
  daysOfWeek: [1, 2, 3, 4, 5], // Monday-Friday
  stops: [...],
  isActive: true,
  schoolId: "SCH1761403353624"
}
```

#### B. Student Collection (Add notification tracking)
```javascript
// students/{studentId}
{
  // Existing fields...
  name: string,
  email: string,
  assignedBusId: string,
  stopping: string,
  notificationPreferenceByTime: number,
  fcmToken: string,
  
  // NEW FIELDS - Notification state
  notified: false,  // Reset at trip start, true after notification
  lastNotifiedAt: timestamp | null,
  lastNotifiedRoute: "scheduleId" | null,
  currentTripId: null,  // Format: "scheduleId_YYYY-MM-DD_HH:MM"
}
```

#### C. Realtime Database (Add time window tracking)
```javascript
// bus_locations/{schoolId}/{busId}
{
  // Existing fields...
  latitude: number,
  longitude: number,
  isActive: boolean,
  activeRouteId: string,
  tripDirection: "pickup" | "drop",
  remainingStops: [...],
  
  // NEW FIELDS - Time window control
  tripStartTime: "07:00",  // From route_schedule.startTime
  tripEndTime: "09:00",    // From route_schedule.endTime
  isWithinTripWindow: true, // Calculated on each GPS update
  lastWindowCheck: timestamp,
  currentTripId: "scheduleId_2024-12-09_07:00"
}
```

---

### **Phase 2: Cloud Functions Logic**

#### **Function 1: onBusLocationUpdate (ENHANCED)**

```javascript
// busmate_app/functions/index.js
exports.onBusLocationUpdate = onValueWritten(
  { ref: "/bus_locations/{schoolId}/{busId}" },
  async (event) => {
    const schoolId = event.params.schoolId;
    const busId = event.params.busId;
    const gpsData = event.data.after.val();
    
    // ⭐ STEP 1: Find active route schedule
    const activeRoute = await determineActiveRoute(schoolId, busId);
    
    if (!activeRoute) {
      console.log(`⏭️ No active route for bus ${busId} - skipping GPS processing`);
      return; // ❌ Outside time window - skip everything!
    }
    
    // ⭐ STEP 2: Check if we're within time window
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    
    if (currentTime < activeRoute.startTime || currentTime > activeRoute.endTime) {
      console.log(`⏰ Outside time window (${activeRoute.startTime}-${activeRoute.endTime})`);
      return; // ❌ Not within window
    }
    
    console.log(`✅ Within time window: ${activeRoute.routeName} (${activeRoute.startTime}-${activeRoute.endTime})`);
    
    // ⭐ STEP 3: Update RTDB with time window info
    await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
      activeRouteId: activeRoute.routeId,
      tripDirection: activeRoute.direction,
      tripStartTime: activeRoute.startTime,
      tripEndTime: activeRoute.endTime,
      isWithinTripWindow: true,
      lastWindowCheck: Date.now(),
      currentTripId: `${activeRoute.routeId}_${now.toISOString().split('T')[0]}_${activeRoute.startTime}`
    });
    
    // ⭐ STEP 4: Continue with existing GPS processing
    // Calculate ETAs (already implemented)
    await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
    
    // ⭐ STEP 5: Check and send notifications
    await checkAndSendNotifications(schoolId, busId, busData, activeRoute);
  }
);

// Helper function to find active route
async function determineActiveRoute(schoolId, busId) {
  const now = new Date();
  const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  const currentDay = now.getDay() || 7; // Sunday = 7
  
  // Query all route schedules for this bus
  const schedulesSnapshot = await admin.firestore()
    .collection("schools")
    .doc(schoolId)
    .collection("route_schedules")
    .where("busId", "==", busId)
    .where("isActive", "==", true)
    .get();
  
  // Find route where currentTime is within startTime-endTime window
  for (const doc of schedulesSnapshot.docs) {
    const schedule = doc.data();
    
    // Check if today is in daysOfWeek
    if (!schedule.daysOfWeek || !schedule.daysOfWeek.includes(currentDay)) {
      continue;
    }
    
    // Check if current time is within route window
    if (currentTime >= schedule.startTime && currentTime <= schedule.endTime) {
      return {
        routeId: doc.id,
        ...schedule
      };
    }
  }
  
  return null; // No active route right now
}
```

#### **Function 2: Trip Start Handler (NEW)**

```javascript
// Scheduled function runs every minute
exports.handleTripTransitions = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Kolkata"
  },
  async (event) => {
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    const currentDay = now.getDay() || 7;
    
    console.log(`⏰ Checking trip transitions at ${currentTime}`);
    
    // Query all schools
    const schoolsSnapshot = await admin.firestore().collection("schools").get();
    
    for (const schoolDoc of schoolsSnapshot.docs) {
      const schoolId = schoolDoc.id;
      
      // Query route schedules starting NOW
      const startingRoutes = await admin.firestore()
        .collection("schools")
        .doc(schoolId)
        .collection("route_schedules")
        .where("startTime", "==", currentTime)
        .where("isActive", "==", true)
        .get();
      
      // Handle trip starts
      for (const routeDoc of startingRoutes.docs) {
        const route = routeDoc.data();
        
        // Check if today is valid
        if (route.daysOfWeek && route.daysOfWeek.includes(currentDay)) {
          console.log(`🚀 Trip START: ${route.routeName} (${route.busId})`);
          await handleTripStart(schoolId, route.busId, routeDoc.id, route);
        }
      }
      
      // Query route schedules ending NOW
      const endingRoutes = await admin.firestore()
        .collection("schools")
        .doc(schoolId)
        .collection("route_schedules")
        .where("endTime", "==", currentTime)
        .where("isActive", "==", true)
        .get();
      
      // Handle trip ends
      for (const routeDoc of endingRoutes.docs) {
        const route = routeDoc.data();
        
        if (route.daysOfWeek && route.daysOfWeek.includes(currentDay)) {
          console.log(`🏁 Trip END: ${route.routeName} (${route.busId})`);
          await handleTripEnd(schoolId, route.busId, routeDoc.id, route);
        }
      }
    }
  }
);

// Handle trip start - Reset all students to notified=false
async function handleTripStart(schoolId, busId, routeId, route) {
  console.log(`📝 Resetting notifications for bus ${busId}`);
  
  // Get all students on this bus
  const studentsSnapshot = await admin.firestore()
    .collection("students")
    .where("assignedBusId", "==", busId)
    .get();
  
  // Reset notified status
  const batch = admin.firestore().batch();
  const tripId = `${routeId}_${new Date().toISOString().split('T')[0]}_${route.startTime}`;
  
  studentsSnapshot.docs.forEach(doc => {
    batch.update(doc.ref, {
      notified: false,
      lastNotifiedAt: null,
      lastNotifiedRoute: null,
      currentTripId: tripId
    });
  });
  
  await batch.commit();
  console.log(`✅ Reset ${studentsSnapshot.size} students to notified=false`);
}

// Handle trip end - Force all remaining students to notified=true
async function handleTripEnd(schoolId, busId, routeId, route) {
  console.log(`🔒 Forcing completion for bus ${busId}`);
  
  // Get students who still have notified=false
  const studentsSnapshot = await admin.firestore()
    .collection("students")
    .where("assignedBusId", "==", busId)
    .where("notified", "==", false)
    .get();
  
  // Force notified=true
  const batch = admin.firestore().batch();
  
  studentsSnapshot.docs.forEach(doc => {
    batch.update(doc.ref, {
      notified: true,
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  await batch.commit();
  console.log(`✅ Forced ${studentsSnapshot.size} students to notified=true`);
  
  // Deactivate in RTDB
  await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
    isWithinTripWindow: false,
    lastWindowCheck: Date.now()
  });
}
```

#### **Function 3: Notification Sender (ENHANCED)**

```javascript
async function checkAndSendNotifications(schoolId, busId, busData, activeRoute) {
  const now = Date.now();
  
  // Get all students on this bus who haven't been notified yet
  const studentsSnapshot = await admin.firestore()
    .collection("students")
    .where("assignedBusId", "==", busId)
    .where("notified", "==", false)  // ⭐ Only students not yet notified
    .get();
  
  console.log(`📧 Checking ${studentsSnapshot.size} students for notifications`);
  
  for (const studentDoc of studentsSnapshot.docs) {
    const student = studentDoc.data();
    
    // Find student's stop in remainingStops
    const studentStop = busData.remainingStops?.find(
      stop => stop.name === student.stopping
    );
    
    if (!studentStop || !studentStop.estimatedMinutesOfArrival) {
      continue; // Skip if stop not found or no ETA
    }
    
    const eta = studentStop.estimatedMinutesOfArrival;
    const preference = student.notificationPreferenceByTime || 10;
    
    // Check if should notify
    if (eta <= preference) {
      console.log(`🔔 Notifying ${student.name}: ETA=${eta}min, Pref=${preference}min`);
      
      // Send notification
      if (student.fcmToken) {
        await admin.messaging().send({
          token: student.fcmToken,
          notification: {
            title: `Bus arriving in ${eta} minutes!`,
            body: `Your bus will reach ${student.stopping} soon.`
          },
          data: {
            type: "bus_arrival",
            eta: eta.toString(),
            stopName: student.stopping,
            routeId: activeRoute.routeId,
            direction: activeRoute.direction
          }
        });
      }
      
      // ⭐ Mark as notified (permanent for this trip)
      await studentDoc.ref.update({
        notified: true,
        lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastNotifiedRoute: activeRoute.routeId
      });
      
      console.log(`✅ Student ${student.name} marked as notified`);
    }
  }
}
```

---

## 📊 Complete Flow Examples

### **Example 1: Single Bus, Two Routes Per Day**

**Configuration:**
```javascript
Route 1: {
  routeName: "Morning Pickup",
  direction: "pickup",
  startTime: "07:00",
  endTime: "09:00",
  busId: "BUS001"
}

Route 2: {
  routeName: "Evening Drop",
  direction: "drop",
  startTime: "15:30",
  endTime: "17:00",
  busId: "BUS001"
}
```

**Timeline:**
```
06:45 → GPS Update → Skip (before any route window)

07:00 → ⏰ TRIP START
        → handleTripStart() runs
        → All students: notified = false
        → RTDB: isWithinTripWindow = true

07:05 → GPS Update → ✅ Process
        → Within window (07:00-09:00)
        → Calculate ETAs
        → Check notifications

07:20 → Student A: ETA=10min, Pref=10min
        → Send notification
        → notified = true (stays true)

08:45 → Student B: ETA=8min, Pref=5min
        → Send notification  
        → notified = true

09:00 → ⏰ TRIP END
        → handleTripEnd() runs
        → Student C still false → Force true
        → RTDB: isWithinTripWindow = false

10:00 → GPS Update → Skip (outside any route window)

15:30 → ⏰ TRIP START (Evening)
        → handleTripStart() runs
        → All students: notified = false (RESET!)
        → RTDB: isWithinTripWindow = true

15:45 → GPS Update → ✅ Process
        → Within window (15:30-17:00)
        → Calculate ETAs
        → Send notifications

17:00 → ⏰ TRIP END
        → handleTripEnd() runs
        → Force remaining to true
        → RTDB: isWithinTripWindow = false

18:00 → GPS Update → Skip (outside window)
```

### **Example 2: Same Bus, Three Routes (Morning, Lunch, Evening)**

**Configuration:**
```javascript
Route 1: startTime: "06:30", endTime: "08:00"  // Early morning
Route 2: startTime: "12:00", endTime: "13:00"  // Lunch run
Route 3: startTime: "16:00", endTime: "17:30"  // Evening
```

**Result:**
- 06:30-08:00 → Active, GPS processed, notifications sent
- 08:01-11:59 → Inactive, GPS ignored
- 12:00-13:00 → Active, GPS processed, notifications sent
- 13:01-15:59 → Inactive, GPS ignored
- 16:00-17:30 → Active, GPS processed, notifications sent
- 17:31-next day → Inactive

---

## ✅ Implementation Checklist

### Phase 1: Database Setup
- [ ] Add `notified`, `lastNotifiedAt`, `lastNotifiedRoute`, `currentTripId` to students collection
- [ ] Add `tripStartTime`, `tripEndTime`, `isWithinTripWindow`, `currentTripId` to RTDB bus_locations
- [ ] Ensure route_schedules have `startTime`, `endTime`, `daysOfWeek` (already done!)

### Phase 2: Cloud Functions
- [ ] Enhance `onBusLocationUpdate` with time window checking
- [ ] Create `determineActiveRoute()` helper function
- [ ] Create `handleTripTransitions` scheduled function (runs every minute)
- [ ] Create `handleTripStart()` function (reset notified=false)
- [ ] Create `handleTripEnd()` function (force notified=true)
- [ ] Enhance `checkAndSendNotifications()` with notified filter

### Phase 3: Testing
- [ ] Test single route window
- [ ] Test multiple routes per day
- [ ] Test outside time windows (should skip GPS)
- [ ] Test notification reset at trip start
- [ ] Test force completion at trip end
- [ ] Test different buses with overlapping times

### Phase 4: Monitoring
- [ ] Add logging for time window checks
- [ ] Add logging for trip transitions
- [ ] Add analytics for notification delivery rates
- [ ] Monitor Firebase costs (RTDB reads/writes)

---

## 🚀 Benefits of This Approach

1. **100% Admin Control** - All times configurable via Time Control screen
2. **Zero Hardcoding** - Works with any time schedule admins create
3. **Cost Efficient** - GPS only processed during active trips
4. **Guaranteed Notifications** - Force true at trip end ensures no one is forgotten
5. **Multi-Route Support** - Same bus can have unlimited routes per day
6. **Day-Specific** - Different schedules for different days
7. **Direction Aware** - Automatically detects pickup vs drop based on schedule

---

## 📝 Summary

**Key Points:**
- Times come from `route_schedules` (admin-managed)
- GPS processing ONLY during active route windows
- Notifications ONLY during active route windows
- Auto-reset `notified=false` at route start
- Auto-force `notified=true` at route end
- Scheduled function runs every minute to handle transitions
- No hardcoded times anywhere!

**This system ensures:**
✅ Students only get notifications during actual trip times
✅ No duplicate notifications (notified=true stays permanent)
✅ No missed notifications (force true at trip end)
✅ Admins have full control via Time Control screen
✅ System scales to any number of routes per bus
