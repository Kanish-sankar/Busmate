# 🧪 Testing Time-Based Trip Control System

## ✅ What I Fixed

### 1. **Deactivated Conflicting Schedule** ✅
   - The 04:25-06:00 drop route is now **INACTIVE** in RTDB
   - Only one active schedule per bus at a time

### 2. **Enhanced Debug Logging** ✅
   - Added detailed logging to `handleTripTransitions`
   - Shows exactly which schedules are checked
   - Displays day matching logic
   - Reports time window comparisons
   - Warns about multiple active schedules

### 3. **Improved Schedule Conflict Detection** ✅
   - Function now warns if multiple schedules are active for same bus
   - Shows all active schedules with their time windows

### 4. **Better Day Matching Visibility** ✅
   - Shows allowed day numbers and names
   - Displays current day and comparison result
   - Easy to debug day mismatch issues

---

## 🎯 Testing Steps

### **Current Time:** 13:31 IST

### **Step 1: Verify Current State**

Check RTDB to see current schedules:
```powershell
firebase database:get /route_schedules_cache/SCH1761403353624/1QX7a0pKcZozDV5Riq6i
```

**Expected Result:**
- Only **ONE** schedule with `isActive: true` (the 13:17-14:00 one)
- The 04:25-06:00 schedule should be `isActive: false`

---

### **Step 2: Watch Function Logs (Live)**

Open a terminal and run:
```powershell
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"
firebase functions:log --only handleTripTransitions
```

Keep this running. At **13:32** (next minute), you should see detailed logs like:

```
⏰ Checking trip transitions at 13:32 IST (Tuesday)
   🔍 Checking active schedule: Test no-1 - Morning Pickup
      Bus: 1QX7a0pKcZozDV5Riq6i, Times: 13:17 - 14:00
      Days: [1,2,3,4,5]
   ✅ Day matches! Checking time windows...
   ⏰ Start time check: Current=13:32, Start=13:17 (no match)
   ⏰ End time check: Current=13:32, End=14:00 (no match)

📊 Trip Transition Summary:
   Schedules checked: 2
   Active schedules: 1
   Trips started: 0
   Trips ended: 0
```

---

### **Step 3: Create Test Schedule for Auto-Start**

#### Option A: Via Web Admin (Time Control Screen)

1. Go to web admin → Time Control
2. Click "Add New Schedule"
3. Configure:
   - **Bus:** TN 66 EC 9876
   - **Route Name:** "Auto Test - Pickup"
   - **Direction:** Pickup
   - **Start Time:** **13:35** (4 minutes from now)
   - **End Time:** **13:45** (14 minutes from now)
   - **Days:** Monday, Tuesday, Wednesday, Thursday, Friday
   - **Active:** ✅ Yes

4. Click Save

#### Option B: Via Firebase Console

1. Go to Firebase Console → Firestore Database
2. Navigate to: `schools/SCH1761403353624/route_schedules`
3. Add document with these fields:
   ```json
   {
     "schoolId": "SCH1761403353624",
     "busId": "1QX7a0pKcZozDV5Riq6i",
     "busVehicleNo": "TN 66 EC 9876",
     "routeName": "Auto Test - Pickup",
     "direction": "pickup",
     "startTime": "13:35",
     "endTime": "13:45",
     "daysOfWeek": [1, 2, 3, 4, 5],
     "isActive": true,
     "stops": [...] // Copy from existing route
   }
   ```

4. Copy the document ID

5. Add to RTDB cache:
   ```powershell
   firebase database:set /route_schedules_cache/SCH1761403353624/1QX7a0pKcZozDV5Riq6i/<DOCUMENT_ID> -d '{
     "schoolId": "SCH1761403353624",
     "busId": "1QX7a0pKcZozDV5Riq6i",
     "routeName": "Auto Test - Pickup",
     "direction": "pickup",
     "startTime": "13:35",
     "endTime": "13:45",
     "daysOfWeek": [1, 2, 3, 4, 5],
     "isActive": true
   }'
   ```

---

### **Step 4: Watch Auto-Start at 13:35**

**What You Should See in Logs:**

At exactly **13:35**, the function should log:

```
⏰ Checking trip transitions at 13:35 IST (Tuesday)
   🔍 Checking active schedule: Auto Test - Pickup
      Bus: 1QX7a0pKcZozDV5Riq6i, Times: 13:35 - 13:45
      Days: [1,2,3,4,5]
   ✅ Day matches! Checking time windows...
   🚀 TRIP START MATCH! Current: 13:35, Start: 13:35
   🚀 Trip start detected for Auto Test - Pickup (Bus 1QX7a0pKcZozDV5Riq6i)
   🔄 Reset X students to notified=false for trip...
   ✅ Trip started successfully

📊 Trip Transition Summary:
   Schedules checked: 2
   Active schedules: 1
   Trips started: 1
   Trips ended: 0
```

---

### **Step 5: Verify in RTDB**

After trip starts at 13:35, check:

```powershell
firebase database:get /bus_locations/SCH1761403353624/1QX7a0pKcZozDV5Riq6i
```

**Expected Fields:**
```json
{
  "isActive": true,
  "isWithinTripWindow": true,
  "activeRouteId": "<DOCUMENT_ID>",
  "scheduleStartTime": "13:35",
  "scheduleEndTime": "13:45",
  "currentTripId": "...",
  "tripStartedAt": <timestamp>,
  "remainingStops": [...]
}
```

---

### **Step 6: Verify Students Reset**

Check Firestore:

```
schooldetails/SCH1761403353624/students
```

Filter by: `assignedBusId == "1QX7a0pKcZozDV5Riq6i"`

**All students should have:**
- `notified: false` ✅
- `currentTripId: "..."` ✅
- `tripStartedAt: <timestamp>` ✅

---

### **Step 7: Test GPS Processing**

Send GPS update (from mobile app or simulator) and check logs:

```
📍 GPS Update: Bus 1QX7a0pKcZozDV5Riq6i
⏰ Current Time: 13:36
🛣️ Active Route: Auto Test - Pickup (pickup)
✅ Route within cached time window
🆕 Calculating initial ETAs with route stops
```

---

### **Step 8: Watch Auto-End at 13:45**

At exactly **13:45**, the function should log:

```
⏰ Checking trip transitions at 13:45 IST (Tuesday)
   🔍 Checking active schedule: Auto Test - Pickup
      Bus: 1QX7a0pKcZozDV5Riq6i, Times: 13:35 - 13:45
      Days: [1,2,3,4,5]
   ✅ Day matches! Checking time windows...
   ⏰ Start time check: Current=13:45, Start=13:35 (no match)
   🏁 TRIP END MATCH! Current: 13:45, End: 13:45
   🏁 Trip end detected for Auto Test - Pickup (Bus 1QX7a0pKcZozDV5Riq6i)
   ✅ Forced X students to notified=true at trip end
   ✅ Trip ended successfully

📊 Trip Transition Summary:
   Schedules checked: 2
   Active schedules: 1
   Trips started: 0
   Trips ended: 1
```

---

## 🔍 Troubleshooting

### **Issue: No logs showing after deployment**

**Solution:** Wait up to 2 minutes for the new function code to be active. The function runs every minute.

---

### **Issue: "0 schedules checked"**

**Cause:** RTDB cache is empty

**Solution:**
```powershell
firebase database:get /route_schedules_cache
```

If empty, go to Time Control screen and click "Save" on any schedule to rebuild cache.

---

### **Issue: "Day mismatch"**

**Cause:** Schedule not configured for current day

**Solution:** Check the logs for:
```
📅 Day Match Check:
   Allowed numbers: [...]
   Current: 2 (tuesday)
```

Make sure current day number is in the allowed list.

---

### **Issue: Trip starts but GPS not processing**

**Cause:** `isWithinTripWindow` not set correctly

**Solution:** Check RTDB:
```powershell
firebase database:get /bus_locations/SCH1761403353624/1QX7a0pKcZozDV5Riq6i/isWithinTripWindow
```

Should be `true` during trip window.

---

## 🎉 Success Indicators

✅ Function logs show detailed schedule checking
✅ Trip auto-starts at exact scheduled time
✅ Students reset to `notified: false`
✅ RTDB shows `isWithinTripWindow: true`
✅ GPS processing works during trip
✅ Trip auto-ends at scheduled end time
✅ Students forced to `notified: true` at end

---

## 📞 Quick Commands Reference

```powershell
# Watch function logs live
firebase functions:log --only handleTripTransitions

# Check RTDB schedules
firebase database:get /route_schedules_cache

# Check bus location
firebase database:get /bus_locations/SCH1761403353624/1QX7a0pKcZozDV5Riq6i

# Deactivate a schedule
firebase database:update /route_schedules_cache/SCH1761403353624/<BUS_ID>/<SCHEDULE_ID> -d '{"isActive": false}'

# Get current IST time
Get-Date -Format "HH:mm"
```

---

## 🎯 Next Steps After Success

1. **Deactivate test schedule** after verification
2. **Set up real schedules** with actual route times
3. **Configure one schedule per bus** (morning or evening)
4. **Monitor logs for first few days** to ensure smooth operation
5. **Verify notifications** are sent to parents at correct times

Good luck! 🚀
