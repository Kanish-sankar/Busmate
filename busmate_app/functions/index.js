const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const nodemailer = require('nodemailer');

admin.initializeApp();

// 🚀 MERGED & OPTIMIZED: Manages bus notifications + trip lifecycle in ONE function
// Replaces: sendBusArrivalNotifications + resetStudentNotifiedStatus          
// Runs every 1 minute for real-time responsiveness (Cloud Scheduler minimum interval)
exports.manageBusNotifications = onSchedule(
  {
    schedule: "every 1 minutes", // Cloud Scheduler minimum interval (30 seconds not supported)
    timeZone: "Asia/Kolkata",
    memory: "512MB", // Increased memory for batch processing
    timeoutSeconds: 540, // Increased timeout for large batches
  },
  async (event) => {
    const db = admin.firestore();
    const rtdb = admin.database();
    const startTime = Date.now();
    console.log(`🚀 Starting notification batch job at ${new Date()}`);

    try {
      // STEP 1: Get all active buses from Realtime Database first
      console.log(`🔍 Fetching all active buses from Realtime Database...`);
      const busLocationsSnapshot = await rtdb.ref('bus_locations').once('value');
      const busLocations = busLocationsSnapshot.val();
      
      if (!busLocations) {
        console.log("📭 No buses found in Realtime Database");
        return;
      }
      
      // Extract active bus IDs and their school IDs
      // Also check for stale GPS data and mark buses inactive if no update for 3+ minutes
      const activeBuses = [];
      const now = Date.now();
      const STALE_THRESHOLD = 3 * 60 * 1000; // 3 minutes (3x the function interval)
      const staleTime = now - STALE_THRESHOLD;
      let staleDataCount = 0;
      
      for (const schoolId in busLocations) {
        for (const busId in busLocations[schoolId]) {
          const busData = busLocations[schoolId][busId];
          
          if (busData && busData.isActive === true) {
            // Check for stale GPS data
            const lastUpdate = busData.lastUpdateTimestamp || 
                              busData.timestamp || 
                              busData.lastETACalculation || 
                              0;
            
            if (lastUpdate < staleTime) {
              const minutesSinceUpdate = Math.floor((now - lastUpdate) / 60000);
              console.log(`⚠️ Bus ${busId} in school ${schoolId} - No GPS for ${minutesSinceUpdate} minutes, marking inactive`);
              
              // Mark bus as inactive
              await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                isActive: false,
                currentStatus: 'InActive',
                staleDataDetected: true,
                lastDeactivatedAt: now,
                deactivationReason: `No GPS data for ${minutesSinceUpdate} minutes`,
              });
              
              staleDataCount++;
            } else if (busData.isWithinTripWindow !== false) {
              activeBuses.push({ schoolId, busId, busData });
              console.log(`✅ Found active bus in trip window: ${busId} in school ${schoolId}`);
            } else {
              console.log(`⏳ Bus ${busId} in school ${schoolId} is active but outside trip window - skipping notifications`);
            }
          }
        }
      }
      
      if (staleDataCount > 0) {
        console.log(`🔴 Deactivated ${staleDataCount} buses due to stale GPS data`);
      }
      
      if (activeBuses.length === 0) {
        console.log("📭 No active buses within trip windows - skipping notification check");
        return;
      }
      
      console.log(`🚌 Found ${activeBuses.length} active buses ready for notifications`);
      
      // 🔀 SHARD BY SCHOOL: Group buses by school for parallel processing
      const busesBySchool = {};
      activeBuses.forEach(({ schoolId, busId, busData }) => {
        if (!busesBySchool[schoolId]) {
          busesBySchool[schoolId] = [];
        }
        busesBySchool[schoolId].push({ busId, busData });
      });
      
      const schoolIds = Object.keys(busesBySchool);
      console.log(`🏫 Processing ${schoolIds.length} schools in parallel`);
      
      // Process each school in parallel (massively improves performance for multi-school setups)
      const allNotifications = [];
      const allUpdates = [];
      
      await Promise.all(schoolIds.map(async (schoolId) => {
        const schoolBuses = busesBySchool[schoolId];
        console.log(`  🏫 School ${schoolId}: Processing ${schoolBuses.length} buses`);
        
        const notifications = [];
        const updates = [];
        
        // Process each active bus in this school
        for (const { busId, busData } of schoolBuses) {
        
        if (!busData.currentTripId) {
          console.log(`Bus ${busId} missing currentTripId - skipping notifications`);
          continue;
        }
        
        // 🕐 ETA DECREMENTATION FALLBACK: Only for buses with stale GPS (1+ min no update)
        // Primary ETA calculation happens in onBusLocationUpdate (every GPS update)
        if (busData.remainingStops && busData.remainingStops.length > 0 && busData.lastETACalculation) {
          const timeSinceLastUpdate = Math.floor((now - busData.lastETACalculation) / 60000);
          if (timeSinceLastUpdate >= 1) {
            console.log(`⏱️ FALLBACK: Decrementing ETAs by ${timeSinceLastUpdate} min (stale GPS)`);
            busData.remainingStops = busData.remainingStops.map(stop => {
              if (stop.estimatedMinutesOfArrival !== null && stop.estimatedMinutesOfArrival !== undefined) {
                const newETA = Math.max(0, stop.estimatedMinutesOfArrival - timeSinceLastUpdate);
                return { ...stop, estimatedMinutesOfArrival: newETA };
              }
              return stop;
            });
            await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
              remainingStops: busData.remainingStops,
              lastETACalculation: now,
            });
          }
        }
        
        // ✅ OPTIMIZATION: Stop detection & notifications moved to onBusLocationUpdate
        // This provides INSTANT processing on every GPS update (10 seconds) instead of 1 minute delay
        // Current function only handles cleanup tasks (stale buses, trip transitions)
        console.log(`⏭️ Bus ${busId} - Primary processing in onBusLocationUpdate (instant notifications)`);
        
      }
      
      // Collect this school's stats
      console.log(`  ✅ School ${schoolId}: Processed ${schoolBuses.length} buses`);
      
      })); // End of Promise.all for school processing

      const endTime = Date.now();
      const duration = endTime - startTime;
      console.log(`⏱️ Cleanup job completed in ${duration}ms`);
      console.log(`📊 Summary: ${activeBuses.length} active buses, ${staleDataCount} marked stale`);
      
    } catch (error) {
      console.error("❌ Error in manageBusNotifications:", error);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// Legacy notification batch code removed. Real-time handling now lives in
// onBusLocationUpdate and processNotificationsForBus.
// ═══════════════════════════════════════════════════════════════════════════

// Scheduled task: handles trip start/end transitions every minute based on admin schedules
exports.handleTripTransitions = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Kolkata",
    memory: "512MB",
    timeoutSeconds: 300,
  },
  async () => {
    const db = admin.firestore();
    const rtdb = admin.database();
    
    // Get current time in IST (UTC + 5:30)
    const nowUTC = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000; // 5 hours 30 minutes in milliseconds
    const nowIST = new Date(nowUTC.getTime() + istOffset);
    
    const currentTime = nowIST.toTimeString().substring(0, 5);
    const currentDayNumber = nowIST.getDay() === 0 ? 7 : nowIST.getDay();
    const currentDayName = nowIST.toLocaleDateString('en-US', { weekday: 'long' });
    const currentDateKey = nowIST.toISOString().split('T')[0];

    console.log(`⏰ Checking trip transitions at ${currentTime} IST (${currentDayName}) [UTC: ${nowUTC.toTimeString().substring(0, 5)}]`);

    const [scheduleSnapshot, busLocationsSnapshot] = await Promise.all([
      rtdb.ref('route_schedules_cache').once('value'),
      rtdb.ref('bus_locations').once('value'),
    ]);

    const schedulesCache = scheduleSnapshot.val() || {};
    const busLocations = busLocationsSnapshot.val() || {};

    let tripsStarted = 0;
    let tripsEnded = 0;
    let schedulesChecked = 0;
    let activeSchedulesFound = 0;

    for (const schoolId in schedulesCache) {
      const schoolSchedules = schedulesCache[schoolId];
      for (const busId in schoolSchedules) {
        const busSchedules = schoolSchedules[busId];
        const busData = busLocations?.[schoolId]?.[busId] || {};

        // Check for multiple active schedules per bus
        const activeSchedules = Object.entries(busSchedules).filter(([_, sched]) => sched?.isActive === true);
        if (activeSchedules.length > 1) {
          console.log(`⚠️ WARNING: Bus ${busId} has ${activeSchedules.length} active schedules:`);
          activeSchedules.forEach(([id, sched]) => {
            console.log(`   - ${id}: ${sched.routeName || 'Unknown'} (${sched.startTime}-${sched.endTime})`);
          });
        }

        for (const routeId in busSchedules) {
          const schedule = busSchedules[routeId];
          schedulesChecked++;
          
          if (!schedule || schedule.isActive === false) {
            console.log(`   ⏭️ Skipping ${routeId} - inactive or null`);
            continue;
          }
          
          activeSchedulesFound++;
          console.log(`   🔍 Checking active schedule: ${schedule.routeName || routeId}`);
          console.log(`      Bus: ${busId}, Times: ${schedule.startTime || 'N/A'} - ${schedule.endTime || 'N/A'}`);
          console.log(`      Days: ${JSON.stringify(schedule.daysOfWeek)}`);

          const dayMatches = scheduleMatchesDay(schedule, currentDayNumber, currentDayName);
          if (!dayMatches) {
            console.log(`   ⏭️ Day mismatch - Current: ${currentDayNumber} (${currentDayName}), Schedule: ${JSON.stringify(schedule.daysOfWeek)}`);
            continue;
          }
          
          console.log(`   ✅ Day matches! Checking time windows...`);

          const startTime = schedule.startTime || "";
          const endTime = schedule.endTime || "";

          // 🔄 CHECK IF BUS IS ACTIVE AND WITHIN THIS SCHEDULE'S TIME WINDOW
          // If yes, update trip direction to match this schedule (handles pickup → drop transitions)
          if (busData.isActive === true && isWithinTripWindow(currentTime, startTime, endTime)) {
            const currentDirection = busData.tripDirection || 'unknown';
            const scheduleDirection = schedule.direction || 'pickup';
            
            if (currentDirection !== scheduleDirection) {
              console.log(`   🔄 DIRECTION CHANGE DETECTED!`);
              console.log(`      Current: ${currentDirection}, Schedule: ${scheduleDirection}`);
              console.log(`      Time window: ${startTime} - ${endTime}`);
              
              const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');
              
              // Update trip direction in RTDB
              await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                tripDirection: scheduleDirection,
                activeRouteId: routeId,
                currentTripId: tripId,
                routeName: schedule.routeName || 'Unknown Route',
              });
              
              // Reset students for new direction
              const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
              const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();
              
              if (!studentsSnapshot.empty) {
                const batch = db.batch();
                studentsSnapshot.forEach((doc) => {
                  batch.update(doc.ref, {
                    notified: false,
                    lastNotifiedRoute: routeId,
                    lastNotifiedAt: null,
                    currentTripId: tripId,
                    tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                });
                await batch.commit();
                console.log(`   ✅ Updated to ${scheduleDirection} direction and reset ${studentsSnapshot.size} students`);
              }
            }
          }

          // 🔄 STUDENT RESET at schedule start time (but NO auto-activation)
          if (startTime && currentTime === startTime) {
            console.log(`   🔄 SCHEDULE START MATCH! Current: ${currentTime}, Start: ${startTime}`);
            const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');
            
            // Reset students to notified=false for this trip window
            const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
            const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();
            
            if (!studentsSnapshot.empty) {
              const batch = db.batch();
              studentsSnapshot.forEach((doc) => {
                batch.update(doc.ref, {
                  notified: false,
                  lastNotifiedRoute: routeId,
                  lastNotifiedAt: null,
                  currentTripId: tripId,
                  tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              });
              await batch.commit();
              console.log(`   ✅ Reset ${studentsSnapshot.size} students to notified=false for trip ${tripId}`);
              console.log(`   ⚠️ NOTE: Trip NOT auto-started - driver must click START TRIP to begin GPS tracking`);
            } else {
              console.log(`   ⚠️ No students assigned to bus ${busId} for reset`);
            }
          } else if (startTime) {
            console.log(`   ⏰ Start time check: Current=${currentTime}, Start=${startTime} (no match)`);
          }

          if (endTime && currentTime === endTime) {
            console.log(`   🏁 TRIP END MATCH! Current: ${currentTime}, End: ${endTime}`);
            const ended = await handleTripEnd({
              db,
              rtdb,
              schoolId,
              busId,
              routeId,
              schedule,
              busData,
            });
            if (ended) {
              tripsEnded++;
              console.log(`   ✅ Trip ended successfully`);
            }
          } else if (endTime) {
            console.log(`   ⏰ End time check: Current=${currentTime}, End=${endTime} (no match)`);
          }
        }
      }
    }

    console.log(`\n📊 Trip Transition Summary:`);
    console.log(`   Schedules checked: ${schedulesChecked}`);
    console.log(`   Active schedules: ${activeSchedulesFound}`);
    console.log(`   Trips started: ${tripsStarted}`);
    console.log(`   Trips ended: ${tripsEnded}`);
    
    if (activeSchedulesFound === 0) {
      console.log(`   ⚠️ No active schedules found - verify route_schedules_cache is populated`);
    }
  }
);

async function handleTripStart({ db, rtdb, schoolId, busId, routeId, schedule, busData, currentDateKey }) {
  const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');

  if (busData?.currentTripId === tripId && busData.isWithinTripWindow === true) {
    console.log(`   ↩️ Trip ${tripId} already active for bus ${busId}`);
    return false;
  }

  console.log(`🚀 Trip start detected for ${schedule.routeName || routeId} (Bus ${busId})`);

  const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
  const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();

  if (!studentsSnapshot.empty) {
    const batch = db.batch();
    studentsSnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        notified: false,
        lastNotifiedRoute: routeId,
        lastNotifiedAt: null,
        currentTripId: tripId,
        tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    console.log(`   🔄 Reset ${studentsSnapshot.size} students to notified=false for trip ${tripId}`);
  } else {
    console.log(`   ⚠️ No students assigned to bus ${busId} for reset`);
  }

  const stops = schedule.stops || [];
  await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
    isActive: true,
    isWithinTripWindow: true,
    activeRouteId: routeId,
    tripDirection: schedule.direction || 'pickup',
    routeName: schedule.routeName || `${schedule.direction || 'Route'}`,
    scheduleStartTime: schedule.startTime,
    scheduleEndTime: schedule.endTime,
    currentTripId: tripId,
    tripStartedAt: Date.now(),
    remainingStops: stops,
    totalStops: stops.length,
    routePolyline: schedule.routePolyline || [],
    deactivationReason: null,
    staleDataDetected: false,
  });

  return true;
}

async function handleTripEnd({ db, rtdb, schoolId, busId, routeId, schedule, busData }) {
  const currentTripId = busData?.currentTripId || buildTripId(routeId, new Date().toISOString().split('T')[0], schedule.startTime || '00:00');

  if (!busData || busData.isWithinTripWindow !== true) {
    console.log(`   ℹ️ Bus ${busId} not marked active during trip end check - forcing completion for trip ${currentTripId}`);
  } else {
    console.log(`🏁 Trip end detected for ${schedule.routeName || routeId} (Bus ${busId})`);
  }

  const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
  const studentsSnapshot = await studentsRef
    .where('assignedBusId', '==', busId)
    .where('notified', '==', false)
    .where('currentTripId', '==', currentTripId)
    .get();

  if (!studentsSnapshot.empty) {
    console.log(`   ℹ️ ${studentsSnapshot.size} students on bus ${busId} did not receive notifications during this trip`);
    console.log(`   📝 These students will be reset for next trip (DO NOT mark as notified=true)`);
    // NOTE: We do NOT mark students as notified=true at trip end
    // They should only be marked notified if they actually received a notification
    // The trip start logic will reset them with new currentTripId for the next trip
  } else {
    console.log(`   ℹ️ No pending students for bus ${busId}`);
  }

  await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
    isWithinTripWindow: false,
    isActive: false,
    currentStatus: 'InActive',
    tripEndedAt: Date.now(),
    deactivationReason: 'Trip schedule ended',
  });

  return true;
}

function findStopData(busStatusData, studentLocationName, studentLocation) {
  // Check if remainingStops exists (bus may have completed route)
  if (!busStatusData.remainingStops || busStatusData.remainingStops.length === 0) {
    console.log(`⚠️ No remaining stops for bus - route may be complete`);
    return null;
  }

  // Normalize student stop name for matching (case-insensitive, trim whitespace)
  const normalizedStudentStop = (studentLocationName || '').toLowerCase().trim();

  // First try to match by name (case-insensitive)
  let stop = busStatusData.remainingStops.find(
    (s) => (s.name || '').toLowerCase().trim() === normalizedStudentStop
  );

  // If no name match and student has location, try matching by coordinates (within ~50m)
  if (!stop && studentLocation && studentLocation.latitude && studentLocation.longitude) {
    console.log(`🔍 No name match, trying location-based matching for (${studentLocation.latitude}, ${studentLocation.longitude})`);
    stop = busStatusData.remainingStops.find((s) => {
      if (!s.latitude || !s.longitude) return false;
      
      // Calculate distance in meters (approximate)
      const latDiff = Math.abs(s.latitude - studentLocation.latitude);
      const lngDiff = Math.abs(s.longitude - studentLocation.longitude);
      const distanceMeters = Math.sqrt(latDiff * latDiff + lngDiff * lngDiff) * 111000; // rough conversion
      
      const isMatch = distanceMeters < 50; // within 50 meters
      if (isMatch) {
        console.log(`✅ Found location match: "${s.name}" at (${s.latitude}, ${s.longitude}) - ${distanceMeters.toFixed(0)}m away`);
      }
      return isMatch;
    });
  }

  if (!stop) {
    console.log(`❌ No matching stop found for ${studentLocationName}`);
    return null;
  }
  
  // Parse ETA - handle both 'eta' (string) and 'estimatedTimeOfArrival' (timestamp) fields
  let etaDate = null;
  let calculatedETA = stop.estimatedMinutesOfArrival;
  
  if (stop.eta) {
    // eta is stored as ISO string like "2025-12-08T07:57:15.129Z"
    etaDate = new Date(stop.eta);
  } else if (stop.estimatedTimeOfArrival) {
    // Legacy format with _seconds timestamp
    etaDate = stop.estimatedTimeOfArrival._seconds 
      ? new Date(stop.estimatedTimeOfArrival._seconds * 1000)
      : new Date(stop.estimatedTimeOfArrival);
  }
  
  // 🚨 FIX: Decrement ETA based on time elapsed since last calculation
  // This ensures ETA decreases every minute even without new GPS data
  if (stop.lastETACalculation && calculatedETA !== null && calculatedETA !== undefined) {
    const lastCalcTime = stop.lastETACalculation;
    const currentTime = Date.now();
    const minutesElapsed = Math.floor((currentTime - lastCalcTime) / 60000);
    
    if (minutesElapsed > 0) {
      // Subtract elapsed time from original ETA
      calculatedETA = Math.max(0, calculatedETA - minutesElapsed);
      console.log(`   ⏰ ETA adjusted: ${stop.estimatedMinutesOfArrival} min - ${minutesElapsed} min elapsed = ${calculatedETA} min`);
    }
  }
  
  return {
    name: stop.name,
    estimatedMinutesOfArrival: calculatedETA,
    originalETA: stop.estimatedMinutesOfArrival,
    eta: etaDate,
  };
}

function getETAInMinutes(data, studentLocationName) {
  const stopData = findStopData(data, studentLocationName);
  if (!stopData) return null;
  return stopData.estimatedMinutesOfArrival;
}

/// Check if parent should be notified for this stop
/// Simplified: Duplicate prevention handled by student.notified flag in Firestore query
/// This function always returns true - notifications controlled by notified=false query filter
function checkShouldNotifyParent(busStatusData, stopName, newETA) {
  // Always allow notification - duplicate prevention handled by Firestore query
  // Students with notified=true are already filtered out in the WHERE clause
  return true;
}


function getSoundName(language) {
  // ✅ FIXED: Now returns correct language-specific sound file
  switch ((language || "").toLowerCase()) {
    case "english":
      return "notification_english";
    case "hindi":
      return "notification_hindi";
    case "tamil":
      return "notification_tamil";
    case "telugu":
      return "notification_telugu";
    case "kannada":
      return "notification_kannada";
    case "malayalam":
      return "notification_malayalam";
    default:
      return "notification_english"; // Default to English if language not recognized
  }
}




// 🗑️ DELETED: resetStudentNotifiedStatus - Merged into manageBusNotifications
// Trip management logic (start/end) now runs in manageBusNotifications every 2 minutes
// This saves 288 function invocations/day and reduces Firestore reads by ~7,000/day

// Helper: Calculate time difference in minutes
function calculateTimeDifference(currentTime, targetTime) {
  const [currentHour, currentMin] = currentTime.split(':').map(Number);
  const [targetHour, targetMin] = targetTime.split(':').map(Number);
  
  const currentMinutes = currentHour * 60 + currentMin;
  const targetMinutes = targetHour * 60 + targetMin;
  
  return currentMinutes - targetMinutes; // Positive if current is after target
}

function scheduleMatchesDay(schedule, currentDayNumber, currentDayName) {
  if (!schedule) {
    console.log(`      ❌ scheduleMatchesDay: null schedule`);
    return false;
  }

  const allowableDayNumbers = new Set();
  const allowableDayNames = new Set();
  const sources = [schedule.daysOfWeek, schedule.days, schedule.activeDays, schedule.allowedDays, schedule.dayFilter];

  const addDay = (value) => {
    if (value === undefined || value === null) {
      return;
    }
    if (typeof value === 'number') {
      allowableDayNumbers.add(value === 0 ? 7 : value);
      return;
    }
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (!trimmed) {
        return;
      }
      const maybeNumber = Number(trimmed);
      if (!Number.isNaN(maybeNumber)) {
        allowableDayNumbers.add(maybeNumber === 0 ? 7 : maybeNumber);
      } else {
        allowableDayNames.add(trimmed.toLowerCase());
      }
      return;
    }
  };

  for (const source of sources) {
    if (!source) {
      continue;
    }
    if (Array.isArray(source)) {
      source.forEach(addDay);
      continue;
    }
    if (typeof source === 'object') {
      Object.entries(source).forEach(([key, value]) => {
        if (value === true || value === 1 || value === 'true') {
          addDay(isNaN(Number(key)) ? key : Number(key));
        }
      });
      continue;
    }
    addDay(source);
  }

  if (allowableDayNumbers.size === 0 && allowableDayNames.size === 0) {
    console.log(`      ℹ️ No day restrictions - schedule active all days`);
    return true;
  }

  const normalizedDayName = (currentDayName || '').toLowerCase();
  const matches = allowableDayNumbers.has(currentDayNumber) || allowableDayNames.has(normalizedDayName);
  
  console.log(`      📅 Day Match Check:`);
  console.log(`         Allowed numbers: [${Array.from(allowableDayNumbers).join(', ')}]`);
  console.log(`         Allowed names: [${Array.from(allowableDayNames).join(', ')}]`);
  console.log(`         Current: ${currentDayNumber} (${normalizedDayName})`);
  console.log(`         Result: ${matches ? '✅ MATCH' : '❌ NO MATCH'}`);
  
  return matches;
}

function isWithinTripWindow(currentTime, startTime, endTime) {
  if (!currentTime || !startTime || !endTime) {
    return false;
  }
  
  const toMinutes = (time) => {
    const [h, m] = time.split(':').map(Number);
    return h * 60 + m;
  };
  
  const current = toMinutes(currentTime);
  const start = toMinutes(startTime);
  const end = toMinutes(endTime);
  
  // Handle overnight schedules (e.g., 23:00 to 01:00)
  if (end < start) {
    return current >= start || current <= end;
  } else {
    return current >= start && current <= end;
  }
}

function buildTripId(routeId, dateKey, startTime) {
  const safeRouteId = (routeId || 'route').replace(/\s+/g, '_');
  const safeDate = dateKey || new Date().toISOString().split('T')[0];
  const safeStart = (startTime || '00:00').replace(':', '');
  return `${safeRouteId}_${safeDate}_${safeStart}`;
}

// 🧪 TESTING ENDPOINT: Manually start a trip (bypasses time check)
exports.manualStartTrip = onRequest(
  { cors: true, region: "us-central1" },
  async (req, res) => {
    try {
      const { schoolId, busId, scheduleId } = req.body;
      
      if (!schoolId || !busId || !scheduleId) {
        return res.status(400).json({ 
          success: false, 
          error: 'schoolId, busId, and scheduleId required' 
        });
      }

      const db = admin.firestore();
      const rtdb = admin.database();
      const currentDateKey = new Date().toISOString().split('T')[0];

      // Fetch schedule
      const scheduleDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('route_schedules')
        .doc(scheduleId)
        .get();

      if (!scheduleDoc.exists) {
        return res.status(404).json({ success: false, error: 'Schedule not found' });
      }

      const schedule = scheduleDoc.data();
      const busSnapshot = await rtdb.ref(`bus_locations/${schoolId}/${busId}`).once('value');
      const busData = busSnapshot.val() || {};

      // Start the trip
      await handleTripStart({
        db,
        rtdb,
        schoolId,
        busId,
        routeId: scheduleId,
        schedule,
        busData,
        currentDateKey,
      });

      return res.status(200).json({ 
        success: true, 
        message: `Trip started for ${schedule.routeName}`,
        tripId: buildTripId(scheduleId, currentDateKey, schedule.startTime || '00:00')
      });
    } catch (error) {
      console.error('Manual trip start error:', error);
      return res.status(500).json({ success: false, error: error.message });
    }
  }
);

// otp generator and send using to mail

// Configure nodemailer
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'jupentabusmate@gmail.com',
    pass: 'ammpdixyhistmxzv',
  },
});

exports.sendOtp = functions.https.onRequest(async (req, res) => {
  const email = req.body.email;

  if (!email) {
    return res.status(400).send({ success: false, message: 'Email is required' });
  }

  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  // Store OTP
  await admin.firestore().collection('otps').doc(email).set({
    otp: otp,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send OTP email
  const mailOptions = {
    from: 'your-email@gmail.com',
    to: email,
    subject: 'Your OTP Code',
    text: `Your OTP code is: ${otp}`,
  };

  try {
    await transporter.sendMail(mailOptions);
    res.status(200).send({ success: true, message: 'OTP sent to email' });
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).send({ success: false, message: 'Failed to send email' });
  }
});


exports.sendCredentialEmail = functions.https.onRequest(async (req, res) => {
  const { email, subject, body } = req.body;

  // Validate input
  if (!email || !subject || !body) {
    return res.status(400).send({ success: false, message: 'Missing fields (email, subject, body) are required.' });
  }

  // Create email options
  const mailOptions = {
    from: 'your-email@gmail.com',
    to: email,
    subject: subject,
    text: body,
    // Optional: if you want HTML emails
    // html: `<p>${body}</p>`
  };

  try {
    await transporter.sendMail(mailOptions);
    res.status(200).send({ success: true, message: 'Email sent successfully.' });
  } catch (error) {
    console.error('Error sending email:', error);
    res.status(500).send({ success: false, message: 'Failed to send email.' });
  }
});

exports.notifyAllStudents = functions.https.onRequest(async (req, res) => {
  const { title, body } = req.body;

  if (!title || !body) {
    return res.status(400).send({ success: false, message: 'Title and body are required.' });
  }

  try {
    const db = admin.firestore();

    // Fetch all user FCM tokens from Firestore
    const snapshot = await db.collection("students").get();

    const tokens = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
      }
    });

    if (tokens.length === 0) {
      return res.status(200).send("No tokens found");
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      android: {
        notification: {
          channelId: "busmate_silent", // Ensure the channel exists in your Android app
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`Success: ${response.responses.filter(r => r.success).length}`);
    console.log(`Failure: ${response.responses.filter(r => !r.success).length}`);

    res.status(200).send(`Notification sent. Success: ${response.responses.filter(r => r.success).length}`);
  } catch (error) {
    console.error("Error sending notification:", error);
    res.status(500).send("Failed to send notification");
  }
});

exports.notifyAllDrivers = functions.https.onRequest(async (req, res) => {
  const { title, body } = req.body;

  if (!title || !body) {
    return res.status(400).send({ success: false, message: 'Title and body are required.' });
  }

  try {
    const db = admin.firestore();

    // Fetch all user FCM tokens from Firestore
    const snapshot = await db.collection("drivers").get();

    const tokens = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
      }
    });

    if (tokens.length === 0) {
      return res.status(200).send("No tokens found");
    }

    const message = {
      notification: {
        title: title,
        body: body,
        sound: "default",
      },
      android: {
        notification: {
          channelId: "busmate_silent", // Ensure the channel exists in your Android app
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`Success: ${response.responses.filter(r => r.success).length}`);
    console.log(`Failure: ${response.responses.filter(r => !r.success).length}`);

    res.status(200).send(`Notification sent. Success: ${response.responses.filter(r => r.success).length}`);
  } catch (error) {
    console.error("Error sending notification:", error);
    res.status(500).send("Failed to send notification");
  }
});

// Hash password function - used when registering/updating students
// Provides secure server-side password hashing to prevent client-side manipulation
exports.hashpassword = onRequest(
  {cors: true, region: "us-central1"},
  async (req, res) => {
    try {
      const bcrypt = require("bcrypt");
      const {password} = req.body;

      if (!password) {
        return res.status(400).json({error: "Password is required"});
      }

      // Hash password with bcrypt (12 salt rounds for good security/performance balance)
      const hashedPassword = await bcrypt.hash(password, 12);

      res.status(200).json({hashedPassword: hashedPassword});
    } catch (error) {
      console.error("Error hashing password:", error);
      res.status(500).json({error: "Failed to hash password"});
    }
  }
);

// Student login function - custom authentication for students (no Firebase Auth)
// This avoids Firebase Auth costs after 50k users while maintaining security
exports.studentlogin = onRequest(
  {cors: true, region: "us-central1"},
  async (req, res) => {
    try {
      const bcrypt = require("bcrypt");
      const {credential, password, schoolId} = req.body;

      if (!credential || !password || !schoolId) {
        return res.status(400).json({
          success: false,
          error: "Credential, password, and schoolId are required",
        });
      }

      // Query Firestore for student with matching credential and schoolId
      const studentsRef = admin.firestore()
        .collection("schools")
        .doc(schoolId)
        .collection("students");

      const querySnapshot = await studentsRef
        .where("email", "==", credential)
        .limit(1)
        .get();

      if (querySnapshot.empty) {
        return res.status(401).json({
          success: false,
          error: "Invalid credentials",
        });
      }

      const studentDoc = querySnapshot.docs[0];
      const studentData = studentDoc.data();

      // Compare password with stored hash
      const passwordMatch = await bcrypt.compare(password, studentData.password);

      if (!passwordMatch) {
        return res.status(401).json({
          success: false,
          error: "Invalid credentials",
        });
      }

      // Generate simple session token (combination of studentId and timestamp)
      // In production, consider using JWT or more secure token generation
      const sessionToken = Buffer.from(
        `${studentDoc.id}:${Date.now()}:${Math.random()}`
      ).toString("base64");

      // Store session token in Firestore with expiry (7 days)
      const expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + 7);

      await admin.firestore()
        .collection("studentSessions")
        .doc(sessionToken)
        .set({
          studentId: studentDoc.id,
          schoolId: schoolId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: expiryDate,
        });

      // Return success with student data and token
      res.status(200).json({
        success: true,
        studentId: studentDoc.id,
        token: sessionToken,
        student: {
          id: studentDoc.id,
          name: studentData.name,
          credential: studentData.email,
          rollNumber: studentData.rollNumber,
          studentClass: studentData.studentClass,
          assignedBusId: studentData.assignedBusId,
          assignedDriverId: studentData.assignedDriverId,
          notificationType: studentData.notificationType,
          languagePreference: studentData.languagePreference,
        },
      });
    } catch (error) {
      console.error("Error during student login:", error);
      res.status(500).json({
        success: false,
        error: "Authentication failed",
      });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Process notifications for a single bus (called from onBusLocationUpdate)
// ═══════════════════════════════════════════════════════════════════════════
async function processNotificationsForBus(schoolId, busId, busData) {
  const db = admin.firestore();
  
  try {
    console.log(`🔔 [Instant Notifications] Checking students for bus ${busId}...`);
    console.log(`   📍 currentTripId: ${busData.currentTripId}`);
    console.log(`   🚏 Remaining stops: ${busData.remainingStops?.length || 0}`);
    console.log(`   🔍 RTDB busData keys: ${Object.keys(busData).join(', ')}`);
    console.log(`   📊 isActive: ${busData.isActive}, isWithinTripWindow: ${busData.isWithinTripWindow}`);
    
    const studentsRef = db.collection(`schooldetails/${schoolId}/students`);

    // Get exact stop names from RTDB (case-sensitive)
    const remainingStopNames = (busData.remainingStops || [])
      .map((s) => s?.name || s?.stopName || "")
      .filter((name) => name);
    const uniqueStopNames = Array.from(new Set(remainingStopNames));
    
    console.log(`   📍 Stop names in RTDB: [${uniqueStopNames.join(', ')}]`);

    if (uniqueStopNames.length === 0) {
      console.log("   ⏭️ No remaining stops - marking all students notified");
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        allStudentsNotified: true,
        noPendingStudents: true,
      });
      return;
    }

    // Simple broad query - get all students for this bus on this trip
    console.log(`   🔍 Querying students: busId=${busId}, notified=false, tripId=${busData.currentTripId}`);
    const snapshot = await studentsRef
      .where('assignedBusId', '==', busId)
      .where('notified', '==', false)
      .where('currentTripId', '==', busData.currentTripId)
      .get();
    
    console.log(`   📊 Broad query returned ${snapshot.size} students`);
    
    // If no students found, check what went wrong
    if (snapshot.size === 0) {
      console.log(`   ⚠️ NO STUDENTS MATCHED! Checking all students for this bus...`);
      const allBusStudents = await studentsRef
        .where('assignedBusId', '==', busId)
        .get();
      
      console.log(`   📊 Total students on bus: ${allBusStudents.size}`);
      allBusStudents.forEach((doc) => {
        const s = doc.data();
        console.log(`   👤 ${s.name} (${doc.id}):`);
        console.log(`      - notified: ${s.notified} (need: false)`);
        console.log(`      - currentTripId: ${s.currentTripId || 'NULL'} (need: ${busData.currentTripId})`);
        console.log(`      - stopping: ${s.stopping || 'NULL'}`);
        console.log(`      - Match: ${s.notified === false && s.currentTripId === busData.currentTripId ? '✅' : '❌'}`);
      });
    }
    
    // Filter in-memory to match stop names (case-sensitive)
    const fetchedDocs = snapshot.docs.filter((doc) => {
      const student = doc.data();
      const studentStopName = student.stopping || student.stopLocation?.name || "";
      const matches = studentStopName && uniqueStopNames.includes(studentStopName);
      
      console.log(`   👤 Student ${doc.id}: stopping="${studentStopName}" - ${matches ? '✅ MATCH' : '❌ NO MATCH'}`);
      
      return matches;
    });
    
    console.log(`   🎯 Final filtered list: ${fetchedDocs.length} students`);

    if (fetchedDocs.length === 0) {
      console.log(`   ⏭️ No pending students found for this bus/trip`);
      
      // Check if trip just started (within 2 minutes) - don't flag yet
      const tripStartedAt = busData.tripStartedAt || 0;
      const timeSinceStart = (Date.now() - tripStartedAt) / 1000 / 60; // minutes
      
      if (timeSinceStart < 2) {
        console.log(`   ⏳ Trip just started (${timeSinceStart.toFixed(1)} min ago) - waiting for student reset`);
        return;
      }
      
      console.log(`   ⏭️ Setting noPendingStudents flag`);
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        allStudentsNotified: true,
        noPendingStudents: true,
      });
      return;
    }
    
    console.log(`   👥 Processing ${fetchedDocs.length} students...`);
    
    const notificationTasks = [];
    
    fetchedDocs.forEach((doc) => {
      const student = doc.data();
      const stopName = (student.stopping || student.stopLocation?.name || '').trim();
      
      if (!stopName || !student.notificationPreferenceByTime) {
        console.log(`   ⚠️ SKIPPED student ${doc.id} - invalid stop/preference`);
        return;
      }
      
      console.log(`   👤 Processing ${student.name} at "${stopName}"`);
      
      const stopData = findStopData(busData, stopName, student.stopLocation);
      
      if (!stopData) {
        console.log(`   ❌ NO STOP DATA for ${student.name} at "${stopName}"`);
        return;
      }
      
      const eta = stopData.estimatedMinutesOfArrival;
      
      // Check if ETA is actually calculated (not null/undefined/NaN)
      if (eta === null || eta === undefined || isNaN(eta)) {
        console.log(`   ❌ NO ETA VALUE for ${student.name} at "${stopName}" (eta=${eta})`);
        return;
      }
      
      console.log(`   📊 ETA: ${eta} min, Preference: ${student.notificationPreferenceByTime} min`);
      
      // Check if notification threshold met
      if (eta !== null && eta !== undefined && eta <= student.notificationPreferenceByTime) {
        console.log(`   🎯 THRESHOLD MET! ${eta.toFixed(1)} min <= ${student.notificationPreferenceByTime} min`);
        
        if (!student.fcmToken) {
          console.log(`   ⚠️ SKIPPED ${student.name} - No FCM token`);
          return;
        }
        
        const isVoiceNotification = (student.notificationType || "").toLowerCase() === "voice notification";
        
        // ✅ HYBRID APPROACH: Include notification field for iOS, suppress on Android
        // iOS: Needs notification field to wake onMessage listener in foreground
        // Android: Will handle in onMessage and show custom notification
        const payload = {
          notification: {
            title: "Bus Approaching!",
            body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
          },
          android: {
            priority: "high",
            ttl: 2 * 60 * 1000,
            // No android.notification field - allows app to handle display
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-expiration": "120000",
            },
            payload: {
              aps: {
                contentAvailable: true,
                // Notification will wake onMessage listener
              },
            },
          },
          data: {
            type: "bus_arrival",
            title: "Bus Approaching!",
            body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
            studentId: doc.id,
            notificationType: isVoiceNotification ? "Voice Notification" : "Text Notification",
            selectedLanguage: student.languagePreference || "english",
            eta: eta.toString(),
            busId: busId,
          },
          token: student.fcmToken,
        };
        
        const tripDirection = busData.tripDirection || 'unknown';
        
        // Queue notification task with student reference
        notificationTasks.push({
          payload,
          docRef: doc.ref,
          studentName: student.name,
          studentId: doc.id,
          updateData: {
            notified: true,
            lastNotifiedRoute: tripDirection,
            lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        });
        
        console.log(`   ✅ QUEUED notification for ${student.name}`);
      } else {
        console.log(`   ⏸️ ETA not met: ${eta?.toFixed(1) || 'N/A'} min > ${student.notificationPreferenceByTime} min`);
      }
    });
    
    // Send notifications and update ONLY on success
    if (notificationTasks.length > 0) {
      console.log(`   📤 Sending ${notificationTasks.length} notifications...`);
      console.log(`   📋 Students to notify: ${notificationTasks.map(t => `${t.studentName} (${t.studentId})`).join(', ')}`);
      
      const successfulUpdates = [];
      
      await Promise.all(notificationTasks.map(async (task) => {
        try {
          console.log(`   🚀 ============================================`);
          console.log(`   🚀 SENDING FCM to ${task.studentId} (${task.studentName})`);
          console.log(`   📱 Token: ${task.payload.token}`);
          console.log(`   📦 Payload:`);
          console.log(`      - Title: ${task.payload.notification.title}`);
          console.log(`      - Body: ${task.payload.notification.body}`);
          console.log(`      - Channel: ${task.payload.android.notification.channelId}`);
          console.log(`      - Sound: ${task.payload.android.notification.sound}`);
          console.log(`      - Priority: ${task.payload.android.priority}`);
          console.log(`      - Data: ${JSON.stringify(task.payload.data)}`);
          
          const sendStartTime = Date.now();
          const result = await admin.messaging().send(task.payload);
          const sendDuration = Date.now() - sendStartTime;
          
          console.log(`   ✅ ============================================`);
          console.log(`   ✅ FCM SEND SUCCESS for ${task.studentId} (${task.studentName})`);
          console.log(`   ✅ Message ID: ${result}`);
          console.log(`   ✅ Send duration: ${sendDuration}ms`);
          console.log(`   ✅ This means FCM accepted the message and will deliver it to the device`);
          console.log(`   ✅ If device doesn't receive: Check device settings, not server issue!`);
          console.log(`   ✅ ============================================`);
          
          // Only mark for update if notification was successfully sent
          successfulUpdates.push({
            ref: task.docRef,
            data: task.updateData,
            studentName: task.studentName
          });
        } catch (error) {
          console.error(`   ❌ ============================================`);
          console.error(`   ❌ FCM SEND FAILED for ${task.studentId} (${task.studentName})`);
          console.error(`   ❌ Error message: ${error.message}`);
          console.error(`   ❌ Error code: ${error.code || 'UNKNOWN'}`);
          console.error(`   ❌ Error stack: ${error.stack}`);
          if (error.errorInfo) {
            console.error(`   ❌ Error info: ${JSON.stringify(error.errorInfo, null, 2)}`);
          }
          console.error(`   ❌ Full error object: ${JSON.stringify(error, null, 2)}`);
          console.error(`   ❌ Token (first 30 chars): ${task.payload.token.substring(0, 30)}...`);
          console.error(`   ❌ Common causes:`);
          console.error(`   ❌   - Invalid/expired FCM token`);
          console.error(`   ❌   - App uninstalled on device`);
          console.error(`   ❌   - Google Play Services not available`);
          console.error(`   ❌ ============================================`);
          console.log(`   🔄 Student ${task.studentId} will remain notified=false for retry`);
        }
      }));
      
      // Update student records ONLY for successful notifications
      if (successfulUpdates.length > 0) {
        console.log(`   💾 Updating ${successfulUpdates.length} students who received notifications...`);
        console.log(`   📝 Updating: ${successfulUpdates.map(u => u.studentName).join(', ')}`);
        const batch = db.batch();
        successfulUpdates.forEach(update => {
          console.log(`   ✍️ Marking ${update.studentName} as notified=true`);
          batch.update(update.ref, update.data);
        });
        await batch.commit();
        console.log(`   ✅ Updated ${successfulUpdates.length} students to notified=true`);
      } else {
        console.log(`   ⚠️ NO students to update - all FCM sends failed!`);
      }
      
      const failedCount = notificationTasks.length - successfulUpdates.length;
      if (failedCount > 0) {
        console.log(`   ⚠️ ${failedCount} students NOT marked as notified due to send failures - will retry on next trigger`);
      }
    }
    
  } catch (error) {
    console.error(`   ❌ Error processing notifications for bus ${busId}:`, error);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UNIFIED GPS ARCHITECTURE - Central ETA Calculator + Instant Notifications
// ═══════════════════════════════════════════════════════════════════════════
// This function triggers whenever GPS data is written to Realtime Database
// from either Driver Phone or Hardware GPS device. It handles:
// - ETA calculation (every 30 seconds)
// - Stop detection (instant on every GPS update)
// - Notification sending (instant when threshold met)
// ═══════════════════════════════════════════════════════════════════════════

const { onValueWritten } = require("firebase-functions/v2/database");
const axios = require("axios");

exports.onBusLocationUpdate = onValueWritten(
  {
    ref: "/bus_locations/{schoolId}/{busId}",
    region: "us-central1",
    memory: "256MB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const schoolId = event.params.schoolId;
    const busId = event.params.busId;
    const gpsData = event.data.after.val();

    if (!gpsData) {
      console.log(`⚠️ No GPS data for bus ${busId}`);
      return;
    }

    console.log(`📍 GPS Update: Bus ${busId} from ${gpsData.source || "unknown"}`);
    console.log(`   Location: (${gpsData.latitude}, ${gpsData.longitude}), Speed: ${gpsData.speed || 0} m/s`);

    try {
      // ✅ OPTIMIZATION: Use event.data.after.val() instead of reading again!
      // This prevents duplicate reads (saves 50% of reads immediately)
      let busData = gpsData; // Use 'let' to allow reassignment after ETA calculation
      
      // Check if this is just a timestamp update (prevent infinite loop)
      // If only lastUpdateTimestamp changed, skip processing
      const previousData = event.data.before.val();
      if (previousData && previousData.latitude === busData.latitude && 
          previousData.longitude === busData.longitude &&
          previousData.isActive === busData.isActive) {
        console.log("   ⏭️ Skipping - only timestamp changed, no actual GPS update");
        return;
      }
      
      // Update lastUpdateTimestamp to track GPS freshness (only on real GPS updates)
      const now = Date.now();
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        lastUpdateTimestamp: now,
      });

      // Check if bus is active
      if (!busData.isActive) {
        console.log("   Bus not active");
        return;
      }

      // Skip ONLY if explicitly set to false (undefined/null means we should check time or allow)
      if (busData.isWithinTripWindow === false) {
        console.log("   ⏭️ Bus outside active trip window - skipping GPS processing");
        return;
      }
      
      // If isWithinTripWindow is undefined, log warning but continue (backward compatibility)
      if (busData.isWithinTripWindow === undefined || busData.isWithinTripWindow === null) {
        console.log("   ⚠️ isWithinTripWindow not set - proceeding with GPS processing (check if trip was started properly)");
      }
      
      // 🚦 TIME-BASED ROUTE ACTIVATION: Determine which route should be active
      const activeRouteInfo = await determineActiveRoute(schoolId, busId, busData);
      
      if (!activeRouteInfo || !activeRouteInfo.routeId) {
        console.log("   ⚠️ No active route - skipping ETA calculation");
        return;
      }
      
      console.log(`   🛣️ Active Route: ${activeRouteInfo.routeName} (${activeRouteInfo.direction})`);
      
      // Check if ETAs need initial calculation (first GPS update after trip start)
      const needsInitialETA = !busData.lastETACalculation || busData.lastETACalculation === 0;
      
      // 🔧 INITIALIZATION: If remainingStops is empty/missing, populate from route schedule
      const needsStopsInitialization = !busData.remainingStops || 
                                        busData.remainingStops.length === 0 || 
                                        busData.remainingStops.some(s => !s.name || s.name.match(/^Stop\d+$/));
      
      if (needsStopsInitialization) {
        console.log(`   🔧 Initializing remainingStops from route schedule (${activeRouteInfo.stoppings.length} stops)`);
        await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          routeName: activeRouteInfo.routeName,
          remainingStops: activeRouteInfo.stoppings,
          totalStops: activeRouteInfo.stoppings.length,
          allStudentsNotified: false,  // Reset flag for new trip
          noPendingStudents: false,    // Reset flag for new trip
        });
        
        // Force initial ETA calculation with proper stops
        console.log(`   🆕 Calculating initial ETAs with route stops`);
        await calculateAndUpdateETAs(schoolId, busId, gpsData, {
          ...busData,
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          remainingStops: activeRouteInfo.stoppings,
        });
        return;
      }
      
      // Update active route in Realtime DB if it changed
      if (busData.activeRouteId !== activeRouteInfo.routeId || 
          busData.tripDirection !== activeRouteInfo.direction) {
        await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          remainingStops: activeRouteInfo.stoppings || busData.remainingStops,
          allStudentsNotified: false,  // Reset flag for route change
          noPendingStudents: false,    // Reset flag for route change
        });
        
        // Force ETA recalculation when route changes
        console.log(`   🔄 Route changed - forcing ETA recalculation`);
        await calculateAndUpdateETAs(schoolId, busId, gpsData, {
          ...busData,
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          remainingStops: activeRouteInfo.stoppings || busData.remainingStops,
        });
        return;
      }
      
      // Calculate ETAs on first GPS update (works for both driver app AND web simulator)
      if (needsInitialETA) {
        console.log(`   🆕 First GPS update - calculating initial ETAs`);
        await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
        
        // CRITICAL: Re-read bus data after ETA calculation to get updated ETAs
        const updatedSnapshot = await admin.database().ref(`bus_locations/${schoolId}/${busId}`).once('value');
        busData = updatedSnapshot.val() || busData;
        console.log(`   ✅ Reloaded bus data with fresh ETAs`);
        console.log(`   📊 First stop ETA: ${busData.remainingStops?.[0]?.estimatedMinutesOfArrival || 'N/A'} min`);
      }
      
      // ⏰ OLA MAPS API RECALCULATION: Every 3 minutes for accurate traffic-aware ETAs
      // Between API calls, ETAs are decremented automatically (time-based)
      const lastCalculation = busData.lastETACalculation || 0;
      const timeSinceLastCalc = (now - lastCalculation) / 1000 / 60; // minutes
      
      let etasRecalculated = false;
      if (timeSinceLastCalc >= 3) {
        console.log(`🚀 3+ minutes elapsed - recalculating ETAs via Ola Maps (${timeSinceLastCalc.toFixed(1)} min since last API call)`);
        await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
        
        // CRITICAL: Re-read bus data after ETA calculation to get updated ETAs
        const updatedSnapshot = await admin.database().ref(`bus_locations/${schoolId}/${busId}`).once('value');
        busData = updatedSnapshot.val() || busData;
        console.log(`   ✅ Reloaded bus data with fresh ETAs`);
        etasRecalculated = true;
      } else {
        console.log(`⏭️ Skipping Ola Maps API - only ${timeSinceLastCalc.toFixed(1)} min since last call (need 3 min)`);
        
        // 📉 DECREMENT ETAs: Between API calls, subtract elapsed time from all stop ETAs
        if (busData.remainingStops && busData.remainingStops.length > 0 && lastCalculation > 0) {
          const elapsedMinutes = (now - lastCalculation) / 1000 / 60; // Convert to minutes
          console.log(`   ⏱️ Decrementing ETAs based on ${elapsedMinutes.toFixed(1)} minutes elapsed`);
          
          let hasValidETAs = false;
          const decrementedStops = busData.remainingStops.map((stop, index) => {
            if (stop.estimatedMinutesOfArrival !== undefined && stop.estimatedMinutesOfArrival !== null) {
              // Simply subtract elapsed minutes from current ETA
              const newETAMinutes = Math.max(0, Math.round(stop.estimatedMinutesOfArrival - elapsedMinutes));
              
              console.log(`      📍 ${stop.name}: ${stop.estimatedMinutesOfArrival} min → ${newETAMinutes} min (decremented)`);
              
              hasValidETAs = true;
              return {
                ...stop,
                estimatedMinutesOfArrival: newETAMinutes,
                eta: stop.eta, // Keep original eta timestamp for reference
                decremented: true, // Flag to indicate this is a decremented ETA
              };
            }
            return stop;
          });
          
          if (hasValidETAs) {
            // Update RTDB with decremented ETAs
            busData.remainingStops = decrementedStops;
            await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
              remainingStops: decrementedStops,
            });
            console.log(`   ✅ Updated ${decrementedStops.length} stops with decremented ETAs`);
          }
        }
      }
      
      // 🚏 INSTANT STOP DETECTION: Check if bus passed any stops (runs on every GPS update!)
      if (busData.remainingStops && busData.remainingStops.length > 0) {
        const STOP_PROXIMITY_THRESHOLD = 200; // meters
        const busLocation = { lat: busData.latitude, lng: busData.longitude };
        const tripDirection = busData.tripDirection || 'pickup';
        let stopsRemoved = 0;
        
        if (tripDirection === 'pickup') {
          // PICKUP: Check stops from START of array (first stop should be reached first)
          const firstStop = busData.remainingStops[0];
          if (firstStop && firstStop.latitude && firstStop.longitude) {
            const distanceToFirst = calculateDistance(busLocation, { lat: firstStop.latitude, lng: firstStop.longitude });
            
            if (distanceToFirst <= STOP_PROXIMITY_THRESHOLD) {
              console.log(`🚏 [PICKUP] Bus ${busId} reached first stop: ${firstStop.name} - REMOVING FROM START`);
              busData.remainingStops.shift(); // Remove from start for pickup
              stopsRemoved = 1;
            } else {
              // Check if bus skipped stops and is near a later stop
              for (let i = 1; i < Math.min(3, busData.remainingStops.length); i++) {
                const stop = busData.remainingStops[i];
                if (!stop || !stop.latitude || !stop.longitude) continue;
                
                const distance = calculateDistance(busLocation, { lat: stop.latitude, lng: stop.longitude });
                
                if (distance <= STOP_PROXIMITY_THRESHOLD) {
                  console.log(`⚠️ [PICKUP] Bus ${busId} skipped ${i} stop(s) and reached stop ${i + 1}: ${stop.name}`);
                  // Remove all skipped stops plus current stop from START
                  for (let j = 0; j <= i; j++) {
                    const removed = busData.remainingStops.shift();
                    console.log(`   🚏 Removed ${j === i ? 'reached' : 'skipped'} stop: ${removed.name}`);
                  }
                  stopsRemoved = i + 1;
                  break;
                }
              }
            }
          }
        } else {
          // DROP: Check stops from END of array (last stop should be reached first)
          const lastStop = busData.remainingStops[busData.remainingStops.length - 1];
          if (lastStop && lastStop.latitude && lastStop.longitude) {
            const distanceToLast = calculateDistance(busLocation, { lat: lastStop.latitude, lng: lastStop.longitude });
            
            if (distanceToLast <= STOP_PROXIMITY_THRESHOLD) {
              console.log(`🚏 [DROP] Bus ${busId} reached last stop: ${lastStop.name} - REMOVING FROM END`);
              busData.remainingStops.pop(); // Remove from end for drop
              stopsRemoved = 1;
            } else {
              // Check if bus skipped stops and is near an earlier stop
              for (let i = busData.remainingStops.length - 2; i >= Math.max(0, busData.remainingStops.length - 3); i--) {
                const stop = busData.remainingStops[i];
                if (!stop || !stop.latitude || !stop.longitude) continue;
                
                const distance = calculateDistance(busLocation, { lat: stop.latitude, lng: stop.longitude });
                
                if (distance <= STOP_PROXIMITY_THRESHOLD) {
                  const skippedCount = busData.remainingStops.length - 1 - i;
                  console.log(`⚠️ [DROP] Bus ${busId} skipped ${skippedCount} stop(s) and reached stop ${i + 1}: ${stop.name}`);
                  // Remove all skipped stops plus current stop from END
                  for (let j = 0; j <= skippedCount; j++) {
                    const removed = busData.remainingStops.pop();
                    console.log(`   🚏 Removed ${j === skippedCount ? 'reached' : 'skipped'} stop: ${removed.name}`);
                  }
                  stopsRemoved = skippedCount + 1;
                  break;
                }
              }
            }
          }
        }
        
        if (stopsRemoved > 0) {
          const newStopsPassedCount = (busData.stopsPassedCount || 0) + stopsRemoved;
          console.log(`   ✅ Stops passed: ${newStopsPassedCount}/${busData.totalStops || 0}`);
          
          // Update immediately
          await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
            remainingStops: busData.remainingStops,
            stopsPassedCount: newStopsPassedCount,
          });
          
          // If all stops completed, mark trip as inactive
          if (busData.remainingStops.length === 0) {
            console.log(`🏁 Bus ${busId} completed all stops - marking inactive`);
            await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
              isActive: false,
              isWithinTripWindow: false,
              currentStatus: 'InActive',
              tripCompletedAt: Date.now(),
            });
            return; // Stop processing
          }
        }
      }
      
      // 🔔 INSTANT NOTIFICATIONS: Check and send notifications on EVERY function trigger (every 30s)
      // This catches students whose notification thresholds are crossed as ETAs decrement
      console.log(`🔔 [Notification Check] currentTripId: ${busData.currentTripId}, remainingStops: ${busData.remainingStops?.length || 0}`);
      console.log(`   allStudentsNotified: ${busData.allStudentsNotified}, noPendingStudents: ${busData.noPendingStudents}`);
      console.log(`   ETAs recalculated: ${etasRecalculated ? 'YES (fresh from API)' : 'NO (using decremented ETAs)'}`);
      
      if (busData.currentTripId && busData.remainingStops && busData.remainingStops.length > 0) {
        // 💡 OPTIMIZATION (Idea 7): Skip when all students already notified or none pending
        if (busData.allStudentsNotified === true || busData.noPendingStudents === true) {
          console.log("   ⏭️ Skipping notifications - all students already notified or none pending");
        } else {
          console.log("   ✅ Processing notifications (checking against current/decremented ETAs)...");
          await processNotificationsForBus(schoolId, busId, busData);
        }
      } else {
        console.log("   ⚠️ Cannot process notifications - missing required data");
      }
      
    } catch (error) {
      console.error(`❌ Error processing GPS update for bus ${busId}:`, error);
    }
  }
);

// Helper: Determine which route should be active (pickup or drop) based on time
async function determineActiveRoute(schoolId, busId, busData) {
  try {
    // Get current time in IST (UTC + 5:30)
    const nowUTC = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000; // 5 hours 30 minutes in milliseconds
    const nowIST = new Date(nowUTC.getTime() + istOffset);
    
    const currentTime = `${nowIST.getHours().toString().padStart(2, '0')}:${nowIST.getMinutes().toString().padStart(2, '0')}`;
    const currentDay = nowIST.getDay() || 7; // Sunday = 7
    const currentDayName = nowIST.toLocaleDateString('en-US', { weekday: 'long' });
    
    console.log(`   ⏰ Current Time: ${currentTime} IST [UTC: ${nowUTC.toTimeString().substring(0, 5)}], Day: ${currentDay}`);
    
    // Get all schedules for this bus from cache
    const schedulesRef = admin.database().ref(`route_schedules_cache/${schoolId}/${busId}`);
    const schedulesSnapshot = await schedulesRef.once('value');
    const allSchedules = schedulesSnapshot.val() || {};
    
    // Check if route is manually activated (but validate if time window expired)
    if (busData.activeRouteId) {
      console.log(`   🎯 Checking active route: ${busData.activeRouteId}`);
      
      // Check if schedule times are already cached in busData (from trip start)
      if (busData.scheduleStartTime && busData.scheduleEndTime) {
        // Handle overnight schedules (e.g., 23:00 - 01:05)
        let isWithinWindow;
        if (busData.scheduleStartTime > busData.scheduleEndTime) {
          // Overnight schedule: current time must be >= start OR <= end
          isWithinWindow = currentTime >= busData.scheduleStartTime || currentTime <= busData.scheduleEndTime;
          console.log(`   🌙 Overnight schedule detected: ${busData.scheduleStartTime} - ${busData.scheduleEndTime}`);
        } else {
          // Normal schedule: current time must be >= start AND <= end
          isWithinWindow = currentTime >= busData.scheduleStartTime && currentTime <= busData.scheduleEndTime;
        }
        
        if (!isWithinWindow) {
          console.log(`   ⚠️ Current route EXPIRED (${busData.scheduleStartTime}-${busData.scheduleEndTime}, current: ${currentTime})`);
          console.log(`   🔍 Searching for matching schedule across all routes...`);
          // Don't return null! Fall through to check all schedules
        } else {
          console.log(`   ✅ Route within cached time window (current: ${currentTime})`);
          // Return immediately without Firestore read!
          return {
            routeId: busData.activeRouteId,
            routeName: busData.routeName || "Active Route",
            direction: busData.tripDirection || "unknown",
            stoppings: busData.remainingStops || [],
          };
        }
      }
    }
    
    // 🔍 SEARCH ALL SCHEDULES: Find which schedule matches current time/day
    console.log(`   🔍 Checking all schedules for time/day match...`);
    for (const [routeId, schedule] of Object.entries(allSchedules)) {
      if (!schedule || schedule.isActive === false) continue;
      
      // Check day match
      const isDayMatch = isDayInSchedule(schedule.daysOfWeek, currentDay, currentDayName);
      if (!isDayMatch) continue;
      
      // Check time window match
      let isTimeMatch;
      if (schedule.startTime > schedule.endTime) {
        // Overnight schedule
        isTimeMatch = currentTime >= schedule.startTime || currentTime <= schedule.endTime;
      } else {
        // Normal schedule
        isTimeMatch = currentTime >= schedule.startTime && currentTime <= schedule.endTime;
      }
      
      if (isTimeMatch) {
        console.log(`   ✅ FOUND MATCHING SCHEDULE: ${schedule.routeName} (${schedule.direction})`);
        console.log(`      Time: ${schedule.startTime} - ${schedule.endTime}, Direction: ${schedule.direction}`);
        
        // Get stops for this direction (already stored separately for pickup/drop)
        const directionStops = schedule.stops || schedule.stoppings || [];
        console.log(`   📍 Using ${directionStops.length} stops from ${schedule.direction} schedule`);
        console.log(`      First stop: ${directionStops[0]?.name || 'Unknown'}`);
        console.log(`      Last stop: ${directionStops[directionStops.length - 1]?.name || 'Unknown'}`);
        
        // Update RTDB if this is different from current active route
        if (busData.activeRouteId !== routeId || busData.tripDirection !== schedule.direction) {
          console.log(`   🔄 SWITCHING to ${schedule.direction} route: ${routeId}`);
          const tripId = buildTripId(routeId, new Date().toISOString().split('T')[0], schedule.startTime || '00:00');
          
          await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
            activeRouteId: routeId,
            tripDirection: schedule.direction || 'pickup',
            routeName: schedule.routeName || 'Unknown Route',
            scheduleStartTime: schedule.startTime,
            scheduleEndTime: schedule.endTime,
            currentTripId: tripId,
            isWithinTripWindow: true,
            remainingStops: directionStops,
            allStudentsNotified: false,
            noPendingStudents: false,
          });
        }
        
        return {
          routeId: routeId,
          routeName: schedule.routeName || "Unknown Route",
          direction: schedule.direction || "unknown",
          stoppings: directionStops,
        };
      }
    }
    
    console.log(`   ⚠️ No active route metadata available for bus ${busId}`);
    return null;
  } catch (error) {
    console.error(`   ❌ Error determining active route: ${error.message}`);
    return null;
  }
}

// Helper: Calculate and update ETAs using Ola Maps API
async function calculateAndUpdateETAs(schoolId, busId, gpsData, busData) {
  const OLA_API_KEY = "c8mw89lGYQ05uglqqr7Val5eUTMRTPqgwMNS6F7h";

  if (!busData.remainingStops || busData.remainingStops.length === 0) {
    console.log(`⚠️ No remaining stops for bus ${busId}`);
    return;
  }

  try {
    // 🚦 Determine trip direction (pickup or drop)
    const tripDirection = busData.tripDirection || 'pickup';
    console.log(`🚦 Trip direction: ${tripDirection}`);
    
    // 🔄 For DROP trips: Reverse the stops order for ETA calculation
    // DROP: Bus travels from school (last stop) → student homes (first stops)
    // So we need to calculate ETAs in reverse order
    const stopsForCalculation = tripDirection === 'drop' 
      ? [...busData.remainingStops].reverse()
      : busData.remainingStops;
    
    console.log(`📍 Calculating ETAs for ${stopsForCalculation.length} stops`);
    console.log(`   First stop: ${stopsForCalculation[0].name}`);
    console.log(`   Last stop: ${stopsForCalculation[stopsForCalculation.length - 1].name}`);
    
    // ✅ Use Ola Maps Directions API (POST with query params, lat,lng order)
    const origin = `${gpsData.latitude},${gpsData.longitude}`;
    const destination = `${stopsForCalculation[stopsForCalculation.length - 1].latitude},${stopsForCalculation[stopsForCalculation.length - 1].longitude}`;

    const waypoints = stopsForCalculation.length > 1
      ? stopsForCalculation
          .slice(0, -1)
          .map((stop) => `${stop.latitude},${stop.longitude}`)
          .join("|")
      : null;

    console.log(`📡 Calling Ola Maps Directions API for ${stopsForCalculation.length} stops (${tripDirection} route)...`);
    console.log(`   Origin: ${origin} (current bus location)`);
    if (waypoints) console.log(`   Waypoints: ${waypoints}`);
    console.log(`   Destination: ${destination}`);

    const params = {
      origin,
      destination,
      mode: "driving",
      api_key: OLA_API_KEY,
    };

    if (waypoints) {
      params.waypoints = waypoints;
    }

    const response = await axios.post(
      "https://api.olamaps.io/routing/v1/directions",
      null,
      {
        params,
        headers: {
          "X-Request-Id": Date.now().toString(),
        },
        timeout: 15000,
      }
    );

    if (
      response.data &&
      response.data.status === "SUCCESS" &&
      response.data.routes &&
      response.data.routes.length > 0
    ) {
      const route = response.data.routes[0];
      const legs = route.legs || [];

      console.log(`✅ Received ${legs.length} route legs from Directions API`);

      // Calculate CUMULATIVE ETAs (time is cumulative, distance is per-leg)
      let cumulativeDuration = 0;
      
      // Map ETAs to the calculation-order stops
      const stopsWithETAs = stopsForCalculation.map((stop, index) => {
        const leg = legs[index];

        if (leg) {
          const legDurationSeconds = leg.duration || 0;
          const legDistanceMeters = leg.distance || 0;
          
          // Add this leg's duration to cumulative total (time is cumulative)
          cumulativeDuration += legDurationSeconds;
          
          const etaMinutes = Math.round(cumulativeDuration / 60);
          const etaTimestamp = new Date(Date.now() + cumulativeDuration * 1000).toISOString();

          console.log(`   📍 ${stop.name}: ${etaMinutes} min, ${(legDistanceMeters / 1000).toFixed(1)} km (leg)`);

          return {
            ...stop,
            estimatedMinutesOfArrival: etaMinutes,
            distanceMeters: legDistanceMeters, // Per-leg distance (not cumulative)
            eta: etaTimestamp,
          };
        }

        return stop;
      });
      
      // 🔄 For DROP trips: Reverse the ETAs back to original order
      // So they match the original remainingStops array order
      const updatedStops = tripDirection === 'drop'
        ? [...stopsWithETAs].reverse()
        : stopsWithETAs;

      // Update Realtime Database with new ETAs (ONLY storage - no Firestore!)
      await admin
        .database()
        .ref(`bus_locations/${schoolId}/${busId}`)
        .update({
          remainingStops: updatedStops,
          lastETACalculation: Date.now(),
        });

      console.log(`✅ Updated ${updatedStops.length} stop ETAs for bus ${busId}`);
    } else {
      console.log(`⚠️ Invalid response from Ola Maps API`);
    }
    } catch (error) {
    console.error(`❌ Error calling Ola Maps API: ${error.message}`);
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Data:`, error.response.data);
    }
    
    // FALLBACK: Calculate ETAs using distance and average speed
    console.log(`⚠️ Using fallback ETA calculation (distance-based) for ${tripDirection} trip`);
    const AVERAGE_SPEED_MPS = 8.33; // 30 km/h = 8.33 m/s (realistic city speed)
    
    // 🚦 For DROP trips: Use reversed stops for calculation
    const stopsForCalculation = tripDirection === 'drop' 
      ? [...busData.remainingStops].reverse()
      : busData.remainingStops;
    
    // Start from current bus location
    let previousLocation = { lat: gpsData.latitude, lng: gpsData.longitude };
    let cumulativeDuration = 0; // Time is still cumulative
    
    const stopsWithETAs = stopsForCalculation.map((stop, index) => {
      // Calculate distance from previous point to this stop
      const legDistance = calculateDistance(
        previousLocation,
        { lat: stop.latitude, lng: stop.longitude }
      );
      
      // Calculate time for this leg
      const legDurationSeconds = legDistance / AVERAGE_SPEED_MPS;
      
      // Add to cumulative time
      cumulativeDuration += legDurationSeconds;
      const etaMinutes = Math.round(cumulativeDuration / 60);
      
      console.log(`   📍 ${stop.name || 'Stop'}: ${etaMinutes} min (cumulative: ${(cumulativeDuration / 60).toFixed(1)} min, leg: ${(legDistance / 1000).toFixed(1)} km) [FALLBACK]`);
      
      // Update previous location for next iteration
      previousLocation = { lat: stop.latitude, lng: stop.longitude };
      
      return {
        ...stop,
        estimatedMinutesOfArrival: etaMinutes,
        distanceMeters: legDistance,
        eta: new Date(Date.now() + cumulativeDuration * 1000).toISOString(),
      };
    });
    
    // 🔄 For DROP trips: Reverse the ETAs back to original order
    const updatedStops = tripDirection === 'drop'
      ? [...stopsWithETAs].reverse()
      : stopsWithETAs;
    
    // Update Realtime Database with fallback ETAs (ONLY storage - no Firestore!)
    await admin
      .database()
      .ref(`bus_locations/${schoolId}/${busId}`)
      .update({
        remainingStops: updatedStops,
        lastETACalculation: Date.now(),
        etaCalculationMethod: 'fallback_distance',
      });
    
    console.log(`✅ Updated ${updatedStops.length} stop ETAs using fallback calculation`);
  }
}// Manual test endpoint to trigger notification logic
exports.testNotifications = onRequest(async (req, res) => {
  console.log("🧪 Manual test notification trigger");
  
  try {
    // Call the same logic as scheduled function
    const db = admin.firestore();
    const rtdb = admin.database();
    
    // Query students
    const studentsSnapshot = await db
      .collectionGroup("students")
      .where("notified", "==", false)
      .where("fcmToken", "!=", null)
      .limit(10)
      .get();
    
    console.log(`📋 Found ${studentsSnapshot.size} students`);
    
    if (studentsSnapshot.empty) {
      return res.json({ success: false, message: "No students found" });
    }
    
    const studentsByBus = new Map();
    
    studentsSnapshot.docs.forEach(doc => {
      const student = doc.data();
      const studentId = doc.id;
      const studentDocRef = doc.ref;
      const stopName = (student.stopping || student.stopLocation?.name || '').trim();
      
      console.log(`👤 Student: ${student.name}, Bus: ${student.assignedBusId}, Stop: ${stopName}`);
      
      if (!student.assignedBusId || !stopName || !student.notificationPreferenceByTime) {
        console.log(`⚠️ Skipped - missing data`);
        return;
      }
      
      if (!studentsByBus.has(student.assignedBusId)) {
        studentsByBus.set(student.assignedBusId, []);
      }
      studentsByBus.get(student.assignedBusId).push({ 
        studentId, 
        studentDocRef, 
        resolvedStopName: stopName, 
        ...student 
      });
    });
    
    console.log(`🚌 Processing ${studentsByBus.size} buses`);
    
    const notifications = [];
    const results = [];
    
    for (const [busId, students] of studentsByBus) {
      console.log(`🚌 Checking bus ${busId}`);
      
      const busSnapshot = await rtdb.ref(`bus_locations/${students[0].schoolId}/${busId}`).once('value');
      const busData = busSnapshot.val();
      
      if (!busData || !busData.isActive) {
        results.push({ busId, status: 'inactive', students: students.length });
        continue;
      }
      
      console.log(`✅ Bus active with ${busData.remainingStops?.length || 0} remaining stops`);
      
      for (const student of students) {
        const stopName = student.resolvedStopName;
        const stopData = findStopData(busData, stopName, student.stopLocation);
        
        if (!stopData || !stopData.eta) {
          results.push({ 
            studentId: student.studentId, 
            status: 'no_eta', 
            stopName,
            availableStops: busData.remainingStops?.map(s => s.name) || []
          });
          continue;
        }
        
        const eta = stopData.estimatedMinutesOfArrival;
        
        console.log(`📊 ${student.name}: ETA ${eta} min, Preference ${student.notificationPreferenceByTime} min`);
        
        if (eta !== null && eta <= student.notificationPreferenceByTime) {
          console.log(`🎯 SHOULD NOTIFY!`);
          
          notifications.push({
            notification: {
              title: "Bus Approaching!",
              body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
            },
            token: student.fcmToken,
            data: {
              type: "bus_arrival",
              studentId: student.studentId,
              eta: eta.toString(),
            }
          });
          
          results.push({ 
            studentId: student.studentId, 
            status: 'queued', 
            eta,
            threshold: student.notificationPreferenceByTime
          });
        } else {
          results.push({ 
            studentId: student.studentId, 
            status: 'eta_not_met', 
            eta,
            threshold: student.notificationPreferenceByTime
          });
        }
      }
    }
    
    console.log(`📤 Sending ${notifications.length} notifications`);
    
    const sendResults = [];
    for (const payload of notifications) {
      try {
        const result = await admin.messaging().send(payload);
        console.log(`✅ Sent! Message ID: ${result}`);
        sendResults.push({ success: true, messageId: result });
      } catch (error) {
        console.error(`❌ Failed:`, error.message);
        sendResults.push({ success: false, error: error.message });
      }
    }
    
    return res.json({ 
      success: true, 
      studentsFound: studentsSnapshot.size,
      busesProcessed: studentsByBus.size,
      notificationsQueued: notifications.length,
      results,
      sendResults
    });
    
  } catch (error) {
    console.error("❌ Test error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// Helper: Calculate distance between two points (Haversine formula)
function calculateDistance(point1, point2) {
  const R = 6371e3; // Earth radius in meters
  const φ1 = (point1.lat * Math.PI) / 180;
  const φ2 = (point2.lat * Math.PI) / 180;
  const Δφ = ((point2.lat - point1.lat) * Math.PI) / 180;
  const Δλ = ((point2.lng - point1.lng) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

// Helper: Get cached schedules for a bus, refreshing from Firestore if missing
async function getCachedSchedulesForBus(schoolId, busId) {
  const cacheRef = admin.database().ref(`route_schedules_cache/${schoolId}/${busId}`);
  const cacheSnapshot = await cacheRef.once('value');
  if (cacheSnapshot.exists()) {
    return cacheSnapshot.val();
  }
  return await refreshBusSchedulesCache(schoolId, busId);
}

// Helper: Refresh bus schedule cache from Firestore (supports legacy + new paths)
async function refreshBusSchedulesCache(schoolId, busId) {
  const db = admin.firestore();
  const cacheRef = admin.database().ref(`route_schedules_cache/${schoolId}/${busId}`);
  const schedules = {};

  const addSchedule = (scheduleId, scheduleData, routeIdOverride) => {
    if (!scheduleData) {
      return;
    }

    const normalized = normalizeScheduleForCache(scheduleId, scheduleData, {
      schoolId,
      busId,
      routeId: routeIdOverride || scheduleData.routeId || scheduleId,
    });

    schedules[scheduleId] = normalized;
  };

  try {
    // Primary collection (schools/{schoolId}/route_schedules)
    const schoolSchedulesSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('route_schedules')
      .where('busId', '==', busId)
      .get();

    schoolSchedulesSnapshot.forEach((doc) => addSchedule(doc.id, doc.data()));

    // Legacy nested structure (schooldetails/{}/buses/{}/routes/{}/route_schedules)
    if (Object.keys(schedules).length === 0) {
      const routesSnapshot = await db
        .collection(`schooldetails/${schoolId}/buses/${busId}/routes`)
        .get();

      for (const routeDoc of routesSnapshot.docs) {
        const routeId = routeDoc.id;
        const routeSchedulesSnapshot = await routeDoc.ref.collection('route_schedules').get();
        routeSchedulesSnapshot.forEach((doc) => addSchedule(doc.id, doc.data(), routeId));
      }
    }

    if (Object.keys(schedules).length === 0) {
      console.log(`   ⚠️ No schedules found in Firestore for bus ${busId}`);
      return null;
    }

    // Persist refreshed cache
    const cachePayload = {};
    for (const [scheduleId, scheduleData] of Object.entries(schedules)) {
      cachePayload[scheduleId] = {
        ...scheduleData,
        lastUpdated: admin.database.ServerValue.TIMESTAMP,
      };
    }

    await cacheRef.set(cachePayload);
    console.log(`   ♻️ Refreshed schedule cache for bus ${busId} (found ${Object.keys(schedules).length} schedules)`);
    return schedules;
  } catch (error) {
    console.error(`   ❌ Failed to refresh schedule cache for bus ${busId}:`, error.message);
    return null;
  }
}

function normalizeScheduleForCache(scheduleId, scheduleData, overrides = {}) {
  return {
    schoolId: overrides.schoolId,
    busId: overrides.busId,
    routeId: overrides.routeId || scheduleId,
    routeName: scheduleData.routeName || 'Route',
    direction: scheduleData.direction || 'pickup',
    daysOfWeek: Array.isArray(scheduleData.daysOfWeek) ? scheduleData.daysOfWeek : [],
    startTime: scheduleData.startTime || '00:00',
    endTime: scheduleData.endTime || '23:59',
    stops: scheduleData.stops || scheduleData.stoppings || [],
    routePolyline: scheduleData.routePolyline || [],
    isActive: scheduleData.isActive !== false,
  };
}

function isDayInSchedule(days, numericDay, dayName) {
  if (!Array.isArray(days)) {
    return false;
  }
  return days.includes(numericDay) || days.includes(dayName);
}
// 🔧 UTILITY: Add missing stoppingLower field to all students
// This fixes the notification query issue where students without stoppingLower are not found
exports.addStoppingLowerField = onRequest(
  { cors: true, region: "us-central1" },
  async (req, res) => {
    try {
      const db = admin.firestore();
      console.log('🔧 Starting stoppingLower field migration...');
      
      // Get all schools
      const schoolsSnapshot = await db.collection('schooldetails').get();
      
      let totalUpdated = 0;
      let totalSkipped = 0;
      
      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;
        console.log(`  📚 Processing school: ${schoolId}`);
        
        // Get all students in this school
        const studentsSnapshot = await db
          .collection(`schooldetails/${schoolId}/students`)
          .get();
        
        console.log(`     Found ${studentsSnapshot.size} students`);
        
        const batch = db.batch();
        let batchCount = 0;
        
        for (const studentDoc of studentsSnapshot.docs) {
          const student = studentDoc.data();
          
          // Skip if stoppingLower already exists
          if (student.stoppingLower) {
            totalSkipped++;
            continue;
          }
          
          // Get stop name from stopping or stopLocation.name
          const stopName = student.stopping || student.stopLocation?.name || '';
          
          if (!stopName) {
            console.log(`     ⚠️ Student ${studentDoc.id} has no stop name - skipping`);
            totalSkipped++;
            continue;
          }
          
          // Create lowercase version
          const stoppingLower = stopName.toLowerCase().trim();
          
          batch.update(studentDoc.ref, { stoppingLower });
          batchCount++;
          totalUpdated++;
          
          // Firestore batch limit is 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            console.log(`     ✅ Committed batch of ${batchCount} students`);
            batchCount = 0;
          }
        }
        
        // Commit remaining updates
        if (batchCount > 0) {
          await batch.commit();
          console.log(`     ✅ Committed final batch of ${batchCount} students`);
        }
      }  
      
      console.log(`✅ Migration complete!`);
      console.log(`   Updated: ${totalUpdated} students`);
      console.log(`   Skipped: ${totalSkipped} students (already had stoppingLower)`);
      
      res.status(200).json({
        success: true,
        message: 'stoppingLower field added successfully',
        updated: totalUpdated,
        skipped: totalSkipped,
      });
    } catch (error) {
      console.error('❌ Error adding stoppingLower field:', error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }
);
