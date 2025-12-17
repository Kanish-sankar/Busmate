# 🧪 Testing Checklist: Drop Route Display Fix

## Pre-Test Setup:
- [ ] App is running (hot reload) OR rebuild app with `flutter run`
- [ ] Firebase Cloud Functions deployed (should already be deployed)
- [ ] Have access to:
  - Parent mobile app (to see UI)
  - Web admin simulator OR driver app (to start trips)
  - Firebase Console (to verify RTDB data)

---

## Test 1: Pickup Route (Should Work As Before)

### Steps:
1. Open web simulator or driver app
2. Select a route
3. Start as **Pickup** trip
4. Open parent app and navigate to live tracking

### Expected Results:
- ✅ Trip direction label shows: "Route Type: Pickup"
- ✅ Stops display in order: Stop1 → Stop2 → Stop3 → School
- ✅ First stop (Stop1) is at the top
- ✅ School is at the bottom
- ✅ As bus passes stops, they move from "upcoming" to "completed"
- ✅ Completed stops show green checkmark and appear at top of list
- ✅ ETAs decrease as bus approaches each stop

---

## Test 2: Drop Route (THE FIX WE JUST APPLIED)

### Steps:
1. Open web simulator or driver app
2. Select a route
3. Start as **Drop** trip (or let scheduler auto-start based on schedule time)
4. Open parent app and navigate to live tracking

### Expected Results:
- ✅ Trip direction label shows: "Route Type: Drop"
- ✅ Stops display in **REVERSED** order: School → Stop3 → Stop2 → Stop1
- ✅ School is at the **top** (first stop)
- ✅ Stop1 is at the **bottom** (last stop)
- ✅ As bus passes stops, first N stops marked as completed
- ✅ Completed stops show green checkmark
- ✅ ETAs decrease as bus approaches each stop
- ✅ ETAs are cumulative (each stop's ETA > previous stop's ETA)

---

## Test 3: Verify RTDB Data Matches App Display

### Steps:
1. Open Firebase Console → Realtime Database
2. Navigate to: `bus_locations/{schoolId}/{busId}`
3. Check current data while drop route is active

### Expected Data:
```json
{
  "tripDirection": "drop",
  "activeRouteId": "5ZWQwPeXAdbUq2YdYDyr",
  "currentTripId": "trip_...",
  "remainingStops": [
    {
      "name": "School",
      "latitude": 12.9716,
      "longitude": 77.5946,
      "distanceMeters": 500,
      "estimatedMinutesOfArrival": 2,
      "eta": "2025-01-..."
    },
    {
      "name": "Stop 3",
      "latitude": ...,
      "longitude": ...,
      "distanceMeters": 2000,
      "estimatedMinutesOfArrival": 8,
      "eta": "2025-01-..."
    }
    // ... more stops in drop order
  ]
}
```

### Verify:
- ✅ `tripDirection` matches what app displays
- ✅ `remainingStops` array is in drop order (School first)
- ✅ ETAs in RTDB match ETAs shown in app

---

## Test 4: Trip Transition (Pickup → Drop on Same Day)

### Steps:
1. Start a **pickup** trip in the morning (7:00 AM - 8:00 AM)
2. Complete the pickup trip
3. Later, start a **drop** trip in the evening (5:00 PM - 6:00 PM)
4. Monitor parent app during both trips

### Expected Results:
- ✅ Morning pickup shows: Stop1 → Stop2 → Stop3 → School
- ✅ Evening drop shows: School → Stop3 → Stop2 → Stop1
- ✅ Completed stops correctly tracked for both trips
- ✅ No overlap between trips (pickup ends before drop starts)

---

## Test 5: Stop Detection During Drop Route

### Steps:
1. Start drop route
2. Use web simulator to move bus to School location (first drop stop)
3. Wait 2-3 minutes for `manageBusNotifications` Cloud Function to run
4. Move bus to Stop3 location
5. Wait 2-3 minutes again
6. Check parent app

### Expected Results:
- ✅ After bus reaches School, it's removed from remainingStops
- ✅ School shows as "completed" in parent app (green checkmark)
- ✅ Stop3 becomes the next "upcoming" stop
- ✅ After bus reaches Stop3, it shows as completed
- ✅ ETAs update correctly as stops are passed

---

## Common Issues & Troubleshooting:

### Issue: App still showing pickup order for drop route
**Possible Causes**:
1. App not reloaded after code changes
2. RTDB `tripDirection` field is missing or incorrect
3. Bus status not being read from RTDB

**Debug Steps**:
- Hot reload the app: Press `r` in Flutter terminal
- Or full restart: Press `R` in Flutter terminal
- Check RTDB in Firebase Console to verify `tripDirection` field exists
- Add debug print: `print("Trip Direction: $tripDirection");` in live_tracking_screen.dart

---

### Issue: Completed stops not showing correctly
**Possible Causes**:
1. `completedStops` calculation is wrong
2. `remainingStops` count not updating in RTDB
3. Stop detection not running

**Debug Steps**:
- Check RTDB: Count items in `remainingStops` array
- Verify Cloud Function logs: `firebase functions:log --only manageBusNotifications`
- Add debug print: `print("Completed: $completedStops, Remaining: $remainingStops");`

---

### Issue: ETAs not decreasing
**Possible Causes**:
1. Stop detection not removing passed stops
2. GPS location not updating
3. Bus not moving (speed < 2.0 km/h)

**Debug Steps**:
- Check Cloud Function logs for stop detection
- Verify bus location is updating in RTDB
- Check `currentSpeed` field in RTDB

---

## Success Criteria:

✅ **All tests pass**
✅ **Drop route shows reversed order: School → Stop3 → Stop2 → Stop1**
✅ **Pickup route still works: Stop1 → Stop2 → Stop3 → School**
✅ **Trip direction label matches actual trip**
✅ **Completed stops appear at top of list**
✅ **ETAs are cumulative and decrease as bus approaches**
✅ **No errors in console or Firebase logs**

---

## Files Modified:

1. `busmate_app/lib/meta/model/bus_model.dart`
   - Added `tripDirection` field
   - Parse from RTDB in `fromMap()`

2. `busmate_app/lib/presentation/parents_module/dashboard/screens/live_tracking_screen.dart`
   - Use `busStatus.tripDirection` instead of `busRouteType`
   - Reverse `allStops` array if `tripDirection == "drop"`
   - Simplified completion logic

---

## Next Steps After Testing:

1. If tests pass → Mark as complete ✅
2. If issues found → Debug using troubleshooting guide above
3. Build release APK if needed: `flutter build apk --release`
4. Share with friend for real-world testing
