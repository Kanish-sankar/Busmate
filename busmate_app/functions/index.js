const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v2");
const { defineSecret, defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// Secrets (Firebase Secret Manager):
// Set these via `firebase functions:secrets:set <NAME>`
const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");
const OLA_MAPS_API_KEY = defineSecret("OLA_MAPS_API_KEY");

// Runtime flags (configured via Firebase Functions params)
const ENABLE_DEBUG_ENDPOINTS = defineString("ENABLE_DEBUG_ENDPOINTS", { default: "false" });
const ENABLE_LEGACY_STUDENTLOGIN = defineString("ENABLE_LEGACY_STUDENTLOGIN", { default: "false" });

function getSecretValue(secretParam, envFallbackName) {
  const fromEnv = envFallbackName ? process.env[envFallbackName] : undefined;
  if (fromEnv) return fromEnv;
  return secretParam.value();
}

function getRoleFromClaims(decoded) {
  return String(decoded?.role || "").trim().toLowerCase();
}

function isSuperiorRole(role) {
  return role === "superior";
}

function isSchoolAdminRole(role) {
  return role === "schooladmin" || role === "school_admin";
}

function isRegionalAdminRole(role) {
  return role === "regionaladmin";
}

async function requireFirebaseAuth(req) {
  const header = String(req.get("authorization") || "");
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const err = new Error("Missing Authorization: Bearer <Firebase ID token>");
    err.statusCode = 401;
    throw err;
  }

  try {
    return await admin.auth().verifyIdToken(match[1]);
  } catch (e) {
    const err = new Error("Invalid/expired Firebase ID token");
    err.statusCode = 401;
    throw err;
  }
}

function assertSameSchoolIfNotSuperior(decoded, targetSchoolId) {
  const role = getRoleFromClaims(decoded);
  if (isSuperiorRole(role)) return;
  const callerSchoolId = String(decoded?.schoolId || "");
  if (!callerSchoolId || !targetSchoolId || callerSchoolId !== targetSchoolId) {
    const err = new Error("Forbidden (school scope mismatch)");
    err.statusCode = 403;
    throw err;
  }
}

let _mailTransporter;
function getMailTransporter() {
  if (_mailTransporter) return _mailTransporter;
  const nodemailer = require("nodemailer");
  const user = getSecretValue(GMAIL_USER, "GMAIL_USER");
  const pass = getSecretValue(GMAIL_APP_PASSWORD, "GMAIL_APP_PASSWORD");
  if (!user || !pass) {
    throw new Error(
      "Email secrets not configured. Set GMAIL_USER and GMAIL_APP_PASSWORD via Secret Manager."
    );
  }
  _mailTransporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user,
      pass,
    },
  });
  return _mailTransporter;
}

// ONE-TIME / DEBUG: bulk-claim fixer.
// Not deployed unless ENABLE_DEBUG_ENDPOINTS=true.
if (ENABLE_DEBUG_ENDPOINTS.value() === "true") {
  exports.fixAllUserClaims = onRequest(
    {
      region: "us-central1",
      cors: true,
    },
    async (req, res) => {
      const db = admin.firestore();

      try {
        const decoded = await requireFirebaseAuth(req);
        if (!isSuperiorRole(getRoleFromClaims(decoded))) {
          return res.status(403).json({ error: "Forbidden" });
        }

        const usersSnapshot = await db.collection("adminusers").get();
        const results = [];

        for (const doc of usersSnapshot.docs) {
          const userData = doc.data();
          const uid = doc.id;
          const role = userData.role;
          const schoolId = userData.schoolId;
          const assignedBusId = userData.assignedBusId;
          const assignedRouteId = userData.assignedRouteId;
          const email = userData.email || "unknown";

          if (!role || !schoolId) {
            results.push({ uid, email, status: "skipped", reason: "missing role or schoolId" });
            continue;
          }

          const claims = { role: String(role).trim().toLowerCase(), schoolId: String(schoolId).trim() };
          if (assignedBusId) claims.assignedBusId = assignedBusId;
          if (assignedRouteId) claims.assignedRouteId = assignedRouteId;

          try {
            await admin.auth().setCustomUserClaims(uid, claims);
            results.push({ uid, email, status: "success", claims });
          } catch (error) {
            console.error(`[fixAllUserClaims] ❌ Failed for ${email}:`, error);
            results.push({ uid, email, status: "error", error: error.message });
          }
        }

        const summary = {
          message: "Claims update complete. Users must log out and back in to get fresh tokens.",
          total: usersSnapshot.docs.length,
          success: results.filter((r) => r.status === "success").length,
          skipped: results.filter((r) => r.status === "skipped").length,
          failed: results.filter((r) => r.status === "error").length,
          results,
        };

        return res.json(summary);
      } catch (error) {
        console.error("[fixAllUserClaims] Fatal error:", error);
        return res.status(error.statusCode || 500).json({ error: error.message });
      }
    }
  );
}

// �🔐 Set custom claims for Firebase Auth users
// Callable function that web admin invokes after creating a new user
// Looks up the user's metadata in `adminusers` and sets role/school claims
exports.setUserClaims = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to call setUserClaims");
    }

    const { uid } = request.data;

    if (!uid) {
      throw new HttpsError("invalid-argument", "Missing uid parameter");
    }


    const db = admin.firestore();

    try {
      // Look up user metadata.
      // Mobile app historically uses `adminusers`, while the web portal uses `admins`.
      // Support both to avoid "permission-denied" when claims are missing.
      let userData = null;
      let source = null;

      const adminUsersDoc = await db.collection("adminusers").doc(uid).get();
      if (adminUsersDoc.exists) {
        userData = adminUsersDoc.data();
        source = "adminusers";
      } else {
        const adminsDoc = await db.collection("admins").doc(uid).get();
        if (adminsDoc.exists) {
          userData = adminsDoc.data();
          source = "admins";
        }
      }

      if (!userData) {
        throw new HttpsError(
          "not-found",
          `No admin metadata found for uid: ${uid} (checked adminusers and admins)`
        );
      }

      const roleRaw = String(userData.role || "");
      const schoolIdRaw = String(userData.schoolId || "");
      const role = roleRaw.trim().toLowerCase();
      const schoolId = schoolIdRaw.trim();
      const assignedBusId = userData.assignedBusId ? String(userData.assignedBusId) : null;
      const assignedRouteId = userData.assignedRouteId ? String(userData.assignedRouteId) : null;

      if (!role) {
        throw new HttpsError("failed-precondition", `No role found for uid: ${uid}`);
      }

      // Authorization:
      // - allow self to refresh their own claims
      // - allow superior / school admin / regional admin to set claims for others (school-scoped)
      const callerRole = String(request.auth.token?.role || "").trim().toLowerCase();
      const callerSchoolId = String(request.auth.token?.schoolId || "").trim();
      const callerIsSuperior = isSuperiorRole(callerRole);
      const callerIsPrivileged = callerIsSuperior || isSchoolAdminRole(callerRole) || isRegionalAdminRole(callerRole);

      if (request.auth.uid !== uid) {
        if (!callerIsPrivileged) {
          throw new HttpsError("permission-denied", "Not allowed to set claims for other users");
        }
        if (!callerIsSuperior && schoolId && callerSchoolId !== schoolId) {
          throw new HttpsError("permission-denied", "School scope mismatch");
        }
      }

      // These roles require a schoolId for scoped access rules.
      if (["student", "driver", "schooladmin", "school_admin", "regionaladmin"].includes(role) && !schoolId) {
        throw new HttpsError(
          "failed-precondition",
          `No schoolId found for uid: ${uid} (role=${role})`
        );
      }

      // Set custom claims for Firestore security rules
      const claims = { role, schoolId };
      if (assignedBusId) claims.assignedBusId = assignedBusId;
      if (assignedRouteId) claims.assignedRouteId = assignedRouteId;

      await admin.auth().setCustomUserClaims(uid, claims);

      
      return { success: true, claims };
    } catch (error) {
      console.error(`[setUserClaims] Error setting claims for ${uid}:`, error);
      throw new HttpsError("internal", `Failed to set claims: ${error.message}`);
    }
  }
);

// 🚀 MERGED & OPTIMIZED: Manages bus notifications + trip lifecycle in ONE function
// Replaces: sendBusArrivalNotifications + resetStudentNotifiedStatus          
// Runs every 1 minute for real-time responsiveness (Cloud Scheduler minimum interval)
exports.manageBusNotifications = onSchedule(
  {
    schedule: "every 1 minutes", // Cloud Scheduler minimum interval (30 seconds not supported)
    timeZone: "Asia/Kolkata",
    memory: "512MB",
    timeoutSeconds: 540,
    region: "us-central1",
    maxInstances: 1,  // ✅ CRITICAL: Prevents concurrent runs that cause double ETA decrements
    secrets: [OLA_MAPS_API_KEY],
  },
  async (event) => {
    const db = admin.firestore();
    const rtdb = admin.database();
    const startTime = Date.now();

    try {
      // STEP 1: Get all active buses from Realtime Database first
      const busLocationsSnapshot = await rtdb.ref('bus_locations').once('value');
      const busLocations = busLocationsSnapshot.val();
      
      if (!busLocations) {
        return;
      }
      
      // Extract active bus IDs and their school IDs
      // Also check for stale GPS data and mark buses inactive if no update for 3+ minutes
      const activeBuses = [];
      const now = Date.now();
      // NOTE: Keep this comfortably larger than the Ola refresh cadence (3 min).
      // If this is too small, buses can be marked inactive before the next Ola refresh.
      const STALE_THRESHOLD = 10 * 60 * 1000; // 10 minutes
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
            } else {
            }
          }
        }
      }
      
      if (staleDataCount > 0) {
      }
      
      if (activeBuses.length === 0) {
        return;
      }
      
      
      // 🔀 SHARD BY SCHOOL: Group buses by school for parallel processing
      const busesBySchool = {};
      activeBuses.forEach(({ schoolId, busId, busData }) => {
        if (!busesBySchool[schoolId]) {
          busesBySchool[schoolId] = [];
        }
        busesBySchool[schoolId].push({ busId, busData });
      });
      
      const schoolIds = Object.keys(busesBySchool);
      
      // Process each school in parallel (massively improves performance for multi-school setups)
      const allNotifications = [];
      const allUpdates = [];
      
      await Promise.all(schoolIds.map(async (schoolId) => {
        const schoolBuses = busesBySchool[schoolId];
        
        const notifications = [];
        const updates = [];
        
        // ✅ PARALLELIZED: Buses within a school are independent — run all concurrently.
        // Previously sequential for-loop → if 50 buses × 300ms OLA call = 15s per school.
        // Now all buses in a school run in parallel → ~300ms regardless of bus count.
        await Promise.all(schoolBuses.map(async ({ busId, busData }) => {

          if (!busData.currentTripId) return;

          // ✅ ETA REFRESH (NO DOUBLE-DECREMENT):
          // Do NOT decrement here. Instead, trigger a real Ola Maps refresh every 3 minutes
          // for ACTIVE buses, even if GPS coordinates didn't change.
          if (busData.isActive && busData.latitude && busData.longitude && busData.remainingStops?.length) {
            const lastOlaAPICall = busData.lastOlaAPICall || busData.lastETACalculation || 0;
            const minutesSinceOla = (now - lastOlaAPICall) / 60000;

            if (lastOlaAPICall === 0 || minutesSinceOla >= 3) {
              try {
                await calculateAndUpdateETAs(
                  schoolId,
                  busId,
                  { latitude: busData.latitude, longitude: busData.longitude },
                  busData
                );
              } catch (e) {
                console.error(`❌ [Scheduled ETA Refresh] Ola Maps failed for bus ${busId}:`, e);
              }
            }
          }

          // 📉 ETA DECREMENT (ON SCHEDULE):
          // - Decrement ONLY here (scheduled every 1 minute, maxInstances:1 prevents double-run)
          // - Decrement from the ORIGINAL ETA baseline (stop.originalETA)
          // - Use whole minutes elapsed since last Ola baseline to avoid rounding jumps
          if (busData.isActive && busData.remainingStops?.length) {
            const lastOlaAPICall = busData.lastOlaAPICall || busData.lastETACalculation || 0;
            if (lastOlaAPICall > 0) {
              const elapsedWholeMinutes = Math.floor((now - lastOlaAPICall) / 60000);

              if (elapsedWholeMinutes >= 1) {
                let anyChanged = false;
                const decrementedStops = busData.remainingStops.map((stop) => {
                  if (stop?.estimatedMinutesOfArrival === undefined || stop?.estimatedMinutesOfArrival === null) {
                    return stop;
                  }

                  const originalETA = (stop.originalETA !== undefined && stop.originalETA !== null)
                    ? stop.originalETA
                    : stop.estimatedMinutesOfArrival;

                  const newETA = Math.max(0, originalETA - elapsedWholeMinutes);
                  if (newETA !== stop.estimatedMinutesOfArrival) anyChanged = true;

                  return {
                    ...stop,
                    originalETA,
                    estimatedMinutesOfArrival: newETA,
                    decremented: true,
                  };
                });

                if (anyChanged) {
                  await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                    remainingStops: decrementedStops,
                    lastETAUpdate: now,
                  });
                }
              }
            }
          }

          // Stop detection & notifications are handled instantly in onBusLocationUpdate.

        })); // End of Promise.all for buses within school

      })); // End of Promise.all for school processing

      const endTime = Date.now();
      const duration = endTime - startTime;
      
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
    region: "us-central1",
    cpu: 0.25,
    maxInstances: 1,
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

    // ✅ PARALLELIZED: Schools and buses are fully independent — run all concurrently.
    // Inner route loop stays sequential per bus because trip-end must run before
    // trip-start (same minute edge case) and busData is refreshed between them.
    await Promise.all(Object.entries(schedulesCache).map(async ([schoolId, schoolSchedules]) => {
      await Promise.all(Object.entries(schoolSchedules).map(async ([busId, busSchedules]) => {
        // Shallow copy so parallel buses never share the same busData object
        const busData = { ...(busLocations?.[schoolId]?.[busId] || {}) };

        // Check for multiple active schedules per bus
        const activeSchedules = Object.entries(busSchedules).filter(([_, sched]) => sched?.isActive === true);
        if (activeSchedules.length > 1) {
          activeSchedules.forEach(([id, sched]) => {
          });
        }

        for (const routeId in busSchedules) {
          const schedule = busSchedules[routeId];
          schedulesChecked++;
          
          if (!schedule || schedule.isActive === false) {
            continue;
          }
          
          activeSchedulesFound++;

          const dayMatches = scheduleMatchesDay(schedule, currentDayNumber, currentDayName);
          if (!dayMatches) {
            continue;
          }
          

          const startTime = schedule.startTime || "";
          const endTime = schedule.endTime || "";

          // 🏁 CRITICAL: Check TRIP END **FIRST** (before any start/direction logic)
          // This prevents Trip 1's end from overriding Trip 2's start when they occur at the same minute (e.g., Trip 1 ends 08:50, Trip 2 starts 08:50)
          if (endTime && currentTime === endTime) {
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
              // Refresh busData after ending so subsequent checks see updated state
              const refreshedSnapshot = await rtdb.ref(`bus_locations/${schoolId}/${busId}`).once('value');
              Object.assign(busData, refreshedSnapshot.val() || {});
            }
          } else if (endTime) {
          }

          // 🔄 CHECK IF BUS IS ACTIVE AND WITHIN THIS SCHEDULE'S TIME WINDOW
          // If yes, update trip direction to match this schedule (handles pickup → drop transitions)
          if (busData.isActive === true && isWithinTripWindow(currentTime, startTime, endTime)) {
            const currentDirection = busData.tripDirection || 'unknown';
            const scheduleDirection = schedule.direction || 'pickup';
            
            if (currentDirection !== scheduleDirection) {
              
              const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');
              const routeRefId = schedule.routeRefId || null;
              const routeRefName = schedule.routeRefName || null;
              
              // Update trip direction in RTDB
              await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                tripDirection: scheduleDirection,
                activeRouteId: routeId,
                routeRefId: routeRefId,
                routeRefName: routeRefName,
                currentTripId: tripId,
                routeName: schedule.routeName || 'Unknown Route',
              });
              
              // Reset students for new direction
              const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
              const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();
              const docsToReset = routeRefId
                ? studentsSnapshot.docs.filter((d) => (d.data() || {}).assignedRouteId === routeRefId)
                : studentsSnapshot.docs;
              
              if (docsToReset.length > 0) {
                const batch = db.batch();
                docsToReset.forEach((doc) => {
                  batch.update(doc.ref, {
                    notified: false,
                    lastNotifiedRoute: routeRefId || routeId,
                    lastNotifiedAt: null,
                    lastNotifiedTripId: null,
                    currentTripId: tripId,
                    tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                });
                await batch.commit();
              } else {
              }
            }
          }

          // 🔄 STUDENT RESET at schedule start time (but NO auto-activation)
          if (startTime && currentTime === startTime) {
            // If driver tracking is already ON (isActive=true), auto-start this trip in RTDB.
            // This solves the case where the app is backgrounded and the UI timers don't run.
            if (busData.isActive === true) {
              const started = await handleTripStart({
                db,
                rtdb,
                schoolId,
                busId,
                routeId,
                schedule,
                busData,
                currentDateKey,
              });
              if (started) {
                tripsStarted++;
              } else {
              }
            } else {
              // Driver tracking is OFF. Only reset students for this trip window.
              const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');
              const routeRefId = schedule.routeRefId || null;

              const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
              const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();
              const docsToReset = routeRefId
                ? studentsSnapshot.docs.filter((d) => (d.data() || {}).assignedRouteId === routeRefId)
                : studentsSnapshot.docs;

              if (docsToReset.length > 0) {
                const batch = db.batch();
                docsToReset.forEach((doc) => {
                  batch.update(doc.ref, {
                    notified: false,
                    lastNotifiedRoute: routeRefId || routeId,
                    lastNotifiedAt: null,
                    lastNotifiedTripId: null,
                    currentTripId: tripId,
                    tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                });
                await batch.commit();
              } else {
              }
            }
          } else if (startTime) {
          }
        }
      }));
    }));

    
    if (activeSchedulesFound === 0) {
    }
  }
);

async function handleTripStart({ db, rtdb, schoolId, busId, routeId, schedule, busData, currentDateKey }) {
  const tripId = buildTripId(routeId, currentDateKey, schedule.startTime || '00:00');

  if (busData?.currentTripId === tripId && busData.isWithinTripWindow === true) {
    return false;
  }


  const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
  const routeRefId = schedule.routeRefId || null;
  const routeRefName = schedule.routeRefName || null;
  const studentsSnapshot = await studentsRef.where('assignedBusId', '==', busId).get();
  const docsToReset = routeRefId
    ? studentsSnapshot.docs.filter((d) => (d.data() || {}).assignedRouteId === routeRefId)
    : studentsSnapshot.docs;

  if (docsToReset.length > 0) {
    const batch = db.batch();
    docsToReset.forEach((doc) => {
      batch.update(doc.ref, {
        notified: false,
        lastNotifiedRoute: routeRefId || routeId,
        lastNotifiedAt: null,
        lastNotifiedTripId: null,
        currentTripId: tripId,
        tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  } else {
  }

  const stops = (schedule.stops || []).map((s) => {
    // Ensure we don't carry ETA fields from a previous trip.
    // ETAs are recomputed by onBusLocationUpdate / scheduled refresh.
    if (!s || typeof s !== 'object') return s;
    const cleaned = { ...s };
    delete cleaned.eta;
    delete cleaned.estimatedTimeOfArrival;
    delete cleaned.estimatedMinutesOfArrival;
    delete cleaned.originalETA;
    return cleaned;
  });

  // 🔄 CRITICAL: Reverse stops for drop direction
  // Firestore stores stops in pickup order (A to Z), but drop runs Z to A
  const direction = (schedule.direction || 'pickup').toLowerCase();
  const orderedStops = direction === 'drop' ? [...stops].reverse() : stops;

  if (orderedStops.length > 0) {
  }

  await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
    isActive: true,
    isWithinTripWindow: true,
    activeRouteId: routeId,
    routeRefId: routeRefId,
    routeRefName: routeRefName,
    tripDirection: schedule.direction || 'pickup',
    routeName: schedule.routeName || `${schedule.direction || 'Route'}`,
    scheduleStartTime: schedule.startTime,
    scheduleEndTime: schedule.endTime,
    currentTripId: tripId,
    tripStartedAt: Date.now(),
    // Force fresh ETA baseline after trip switch.
    // - onBusLocationUpdate will treat this as needsInitialETA
    // - manageBusNotifications scheduled refresh will call Ola immediately (lastOlaAPICall === 0)
    lastETACalculation: 0,
    lastOlaAPICall: 0,
    lastETAUpdate: 0,
    allStudentsNotified: false,
    noPendingStudents: false,
    stopsPassedCount: 0,
    remainingStops: orderedStops,
    totalStops: orderedStops.length,
    routePolyline: schedule.routePolyline || [],
    deactivationReason: null,
    staleDataDetected: false,
  });

  return true;
}

async function handleTripEnd({ db, rtdb, schoolId, busId, routeId, schedule, busData }) {
  const currentTripId = busData?.currentTripId || buildTripId(routeId, new Date().toISOString().split('T')[0], schedule.startTime || '00:00');

  // IMPORTANT: Avoid ending the "wrong" trip at exact boundaries.
  // If the bus has already switched to a different schedule (activeRouteId differs),
  // skip ending this schedule to prevent overriding the new trip state.
  if (busData?.activeRouteId && busData.activeRouteId !== routeId) {
    return false;
  }

  if (!busData || busData.isWithinTripWindow !== true) {
  } else {
  }

  const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
  const studentsSnapshot = await studentsRef
    .where('assignedBusId', '==', busId)
    .where('notified', '==', false)
    .where('currentTripId', '==', currentTripId)
    .get();

  if (!studentsSnapshot.empty) {
    // NOTE: We do NOT mark students as notified=true at trip end
    // They should only be marked notified if they actually received a notification
    // The trip start logic will reset them with new currentTripId for the next trip
  } else {
  }

  // NOTE: Do NOT force isActive=false here.
  // isActive represents driver tracking (Start/Stop Trip button) and the background locator.
  // For background operation, driver tracking can remain ON between trips.
  // We only end the current trip window + clear trip metadata.
  await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
    isWithinTripWindow: false,
    tripEndedAt: Date.now(),
    deactivationReason: 'Trip schedule ended',
    activeRouteId: null,
    routeRefId: null,
    routeRefName: null,
    currentTripId: null,
    routeName: null,
    tripDirection: null,
    scheduleStartTime: null,
    scheduleEndTime: null,
    remainingStops: [],
    totalStops: 0,
    routePolyline: [],
  });

  return true;
}

function findStopData(busStatusData, studentLocationName, studentLocation) {
  // Check if remainingStops exists (bus may have completed route)
  if (!busStatusData.remainingStops || busStatusData.remainingStops.length === 0) {
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
    stop = busStatusData.remainingStops.find((s) => {
      if (!s.latitude || !s.longitude) return false;
      
      // Calculate distance in meters (approximate)
      const latDiff = Math.abs(s.latitude - studentLocation.latitude);
      const lngDiff = Math.abs(s.longitude - studentLocation.longitude);
      const distanceMeters = Math.sqrt(latDiff * latDiff + lngDiff * lngDiff) * 111000; // rough conversion
      
      const isMatch = distanceMeters < 50; // within 50 meters
      if (isMatch) {
      }
      return isMatch;
    });
  }

  if (!stop) {
    return null;
  }
  
  // Parse ETA - handle both 'eta' (string) and 'estimatedTimeOfArrival' (timestamp) fields
  let etaDate = null;
  
  if (stop.eta) {
    // eta is stored as ISO string like "2025-12-08T07:57:15.129Z"
    etaDate = new Date(stop.eta);
  } else if (stop.estimatedTimeOfArrival) {
    // Legacy format with _seconds timestamp
    etaDate = stop.estimatedTimeOfArrival._seconds 
      ? new Date(stop.estimatedTimeOfArrival._seconds * 1000)
      : new Date(stop.estimatedTimeOfArrival);
  }
  
  // ✅ IMPORTANT:
  // Do NOT time-adjust here. ETAs are already updated in RTDB by:
  // - onBusLocationUpdate (on GPS updates)
  // - manageBusNotifications scheduled refresh (every ~1 min, Ola call every 3 min)
  // Time-adjusting here caused DOUBLE DECREMENT.

  return {
    name: stop.name,
    estimatedMinutesOfArrival: stop.estimatedMinutesOfArrival,
    originalETA: stop.originalETA !== undefined ? stop.originalETA : stop.estimatedMinutesOfArrival,
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
    return false;
  }

  const normalizedDayName = (currentDayName || '').toLowerCase();
  const matches = allowableDayNumbers.has(currentDayNumber) || allowableDayNames.has(normalizedDayName);
  
  
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

// 🧪 DEBUG ENDPOINT: Manually start a trip (bypasses time check)
// Not deployed unless ENABLE_DEBUG_ENDPOINTS=true.
if (ENABLE_DEBUG_ENDPOINTS.value() === "true") {
  exports.manualStartTrip = onRequest(
    { cors: true, region: "us-central1" },
    async (req, res) => {
      try {
        const decoded = await requireFirebaseAuth(req);
        const role = getRoleFromClaims(decoded);
        if (!isSuperiorRole(role) && !isSchoolAdminRole(role) && !isRegionalAdminRole(role)) {
          return res.status(403).json({ success: false, error: "Forbidden" });
        }

        const { schoolId, busId, scheduleId } = req.body;

        if (!schoolId || !busId || !scheduleId) {
          return res.status(400).json({
            success: false,
            error: "schoolId, busId, and scheduleId required",
          });
        }

        assertSameSchoolIfNotSuperior(decoded, schoolId);

        const db = admin.firestore();
        const rtdb = admin.database();
        const currentDateKey = new Date().toISOString().split("T")[0];

        const scheduleDoc = await db
          .collection("schools")
          .doc(schoolId)
          .collection("route_schedules")
          .doc(scheduleId)
          .get();

        if (!scheduleDoc.exists) {
          return res.status(404).json({ success: false, error: "Schedule not found" });
        }

        const schedule = scheduleDoc.data();
        const busSnapshot = await rtdb.ref(`bus_locations/${schoolId}/${busId}`).once("value");
        const busData = busSnapshot.val() || {};

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
          tripId: buildTripId(scheduleId, currentDateKey, schedule.startTime || "00:00"),
        });
      } catch (error) {
        console.error("Manual trip start error:", error);
        return res.status(error.statusCode || 500).json({ success: false, error: error.message });
      }
    }
  );
}

// OTP is requested BEFORE login, so it cannot require Firebase Auth.
// To reduce abuse, restrict to known admin emails + rate-limit.
exports.sendOtp = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [GMAIL_USER, GMAIL_APP_PASSWORD],
  },
  async (req, res) => {
    const email = String(req.body?.email || "").trim().toLowerCase();

    if (!email) {
      return res.status(400).send({ success: false, message: "Email is required" });
    }

    try {
      const db = admin.firestore();

      // Allow OTP only for emails that exist in admin metadata.
      // This prevents spamming arbitrary addresses.
      const [adminsSnap, adminUsersSnap] = await Promise.all([
        db.collection("admins").where("email", "==", email).limit(1).get(),
        db.collection("adminusers").where("email", "==", email).limit(1).get(),
      ]);

      if (adminsSnap.empty && adminUsersSnap.empty) {
        // Avoid leaking whether an email exists.
        return res.status(200).send({ success: true, message: "OTP sent to email" });
      }

      // Simple per-email rate limit: 5 OTPs per hour
      const rateDocRef = db.collection("otp_rate_limits").doc(email);
      const rateDoc = await rateDocRef.get();
      const now = Date.now();
      const windowMs = 60 * 60 * 1000;
      const maxPerWindow = 5;
      const rateData = rateDoc.exists ? rateDoc.data() : null;
      const windowStart = Number(rateData?.windowStartMs || 0);
      const count = Number(rateData?.count || 0);

      const inWindow = windowStart > 0 && now - windowStart < windowMs;
      const nextCount = inWindow ? count + 1 : 1;
      const nextWindowStart = inWindow ? windowStart : now;

      if (inWindow && nextCount > maxPerWindow) {
        return res.status(429).send({
          success: false,
          message: "Too many OTP requests. Please try again later.",
        });
      }

      await rateDocRef.set(
        {
          windowStartMs: nextWindowStart,
          count: nextCount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      const otp = Math.floor(100000 + Math.random() * 900000).toString();

      await db.collection("otps").doc(email).set({
        otp,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const mailOptions = {
        from: getSecretValue(GMAIL_USER, "GMAIL_USER"),
        to: email,
        subject: "Your OTP Code",
        text: `Your OTP code is: ${otp}`,
      };

      await getMailTransporter().sendMail(mailOptions);
      return res.status(200).send({ success: true, message: "OTP sent to email" });
    } catch (error) {
      console.error("Error sending OTP:", error);
      return res.status(500).send({ success: false, message: "Failed to send email" });
    }
  }
);


exports.sendCredentialEmail = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [GMAIL_USER, GMAIL_APP_PASSWORD],
  },
  async (req, res) => {
    try {
      const decoded = await requireFirebaseAuth(req);
      const role = getRoleFromClaims(decoded);

      if (!isSuperiorRole(role) && !isSchoolAdminRole(role) && !isRegionalAdminRole(role)) {
        return res.status(403).send({ success: false, message: "Forbidden" });
      }

      const email = String(req.body?.email || "").trim();
      const subject = String(req.body?.subject || "").trim();
      const body = String(req.body?.body || "");

      if (!email || !subject || !body) {
        return res
          .status(400)
          .send({ success: false, message: "Missing fields (email, subject, body) are required." });
      }

      const mailOptions = {
        from: getSecretValue(GMAIL_USER, "GMAIL_USER"),
        to: email,
        subject,
        text: body,
      };

      await getMailTransporter().sendMail(mailOptions);
      return res.status(200).send({ success: true, message: "Email sent successfully." });
    } catch (error) {
      console.error("Error sending email:", error);
      return res.status(error.statusCode || 500).send({ success: false, message: "Failed to send email." });
    }
  }
);

exports.notifyAllStudents = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    try {
      const decoded = await requireFirebaseAuth(req);
      const role = getRoleFromClaims(decoded);
      if (!isSuperiorRole(role) && !isSchoolAdminRole(role) && !isRegionalAdminRole(role)) {
        return res.status(403).send({ success: false, message: "Forbidden" });
      }

      const schoolId = String(req.body?.schoolId || "").trim();
      const title = String(req.body?.title || "").trim();
      const body = String(req.body?.body || "").trim();

      if (!schoolId || !title || !body) {
        return res.status(400).send({
          success: false,
          message: "schoolId, title and body are required.",
        });
      }

      assertSameSchoolIfNotSuperior(decoded, schoolId);

      const db = admin.firestore();

      // Determine which collection path has students
      const primaryRef = db.collection(`schooldetails/${schoolId}/students`);
      const probe = await primaryRef.limit(1).get();
      const collectionRef = probe.empty
        ? db.collection(`schools/${schoolId}/students`)
        : primaryRef;

      // Paginate in batches of 500 to avoid loading all docs into memory at once.
      // FCM sendEachForMulticast also enforces a hard limit of 500 tokens per call.
      const BATCH_SIZE = 500;
      let lastDoc = null;
      let totalSuccess = 0;
      let totalFailure = 0;
      let totalTokens = 0;

      while (true) {
        let query = collectionRef.orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
        if (lastDoc) query = query.startAfter(lastDoc);

        const page = await query.get();
        if (page.empty) break;

        const tokens = [];
        page.forEach((doc) => {
          const data = doc.data() || {};
          if (data.fcmToken) tokens.push(data.fcmToken);
        });

        if (tokens.length > 0) {
          const message = {
            notification: { title, body },
            android: { notification: { channelId: "busmate_silent", sound: "default" } },
            apns: { payload: { aps: { sound: "default" } } },
            tokens,
          };
          const response = await admin.messaging().sendEachForMulticast(message);
          totalSuccess += response.responses.filter((r) => r.success).length;
          totalFailure += response.responses.length - response.responses.filter((r) => r.success).length;
          totalTokens += tokens.length;
        }

        lastDoc = page.docs[page.docs.length - 1];
        if (page.size < BATCH_SIZE) break; // last page
      }

      if (totalTokens === 0) {
        return res.status(200).send({ success: true, message: "No tokens found" });
      }

      return res.status(200).send({ success: true, successCount: totalSuccess, failureCount: totalFailure });
    } catch (error) {
      console.error("Error sending student notification:", error);
      return res
        .status(error.statusCode || 500)
        .send({ success: false, message: "Failed to send notification" });
    }
  }
);

exports.notifyAllDrivers = onRequest(
  { region: "us-central1", cors: true },
  async (req, res) => {
    try {
      const decoded = await requireFirebaseAuth(req);
      const role = getRoleFromClaims(decoded);
      if (!isSuperiorRole(role) && !isSchoolAdminRole(role) && !isRegionalAdminRole(role)) {
        return res.status(403).send({ success: false, message: "Forbidden" });
      }

      const schoolId = String(req.body?.schoolId || "").trim();
      const title = String(req.body?.title || "").trim();
      const body = String(req.body?.body || "").trim();

      if (!schoolId || !title || !body) {
        return res.status(400).send({
          success: false,
          message: "schoolId, title and body are required.",
        });
      }

      assertSameSchoolIfNotSuperior(decoded, schoolId);

      const db = admin.firestore();

      // Paginate driver tokens in batches of 500 (FCM hard limit per sendEachForMulticast call).
      const BATCH_SIZE = 500;
      let lastDoc = null;
      let totalSuccess = 0;
      let totalFailure = 0;
      let totalTokens = 0;

      while (true) {
        let query = db
          .collection("adminusers")
          .where("schoolId", "==", schoolId)
          .orderBy(admin.firestore.FieldPath.documentId())
          .limit(BATCH_SIZE);
        if (lastDoc) query = query.startAfter(lastDoc);

        const page = await query.get();
        if (page.empty) break;

        const tokens = [];
        page.forEach((doc) => {
          const data = doc.data() || {};
          const r = String(data.role || "").toLowerCase();
          if (r.includes("driver") && data.fcmToken) tokens.push(data.fcmToken);
        });

        if (tokens.length > 0) {
          const message = {
            notification: { title, body },
            android: { notification: { channelId: "busmate_silent", sound: "default" } },
            apns: { payload: { aps: { sound: "default" } } },
            tokens,
          };
          const response = await admin.messaging().sendEachForMulticast(message);
          totalSuccess += response.responses.filter((r) => r.success).length;
          totalFailure += response.responses.length - response.responses.filter((r) => r.success).length;
          totalTokens += tokens.length;
        }

        lastDoc = page.docs[page.docs.length - 1];
        if (page.size < BATCH_SIZE) break; // last page
      }

      if (totalTokens === 0) {
        return res.status(200).send({ success: true, message: "No tokens found" });
      }

      return res.status(200).send({ success: true, successCount: totalSuccess, failureCount: totalFailure });
    } catch (error) {
      console.error("Error sending driver notification:", error);
      return res
        .status(error.statusCode || 500)
        .send({ success: false, message: "Failed to send notification" });
    }
  }
);

// DEBUG ONLY: Hash password endpoint (avoid exposing CPU work publicly in prod)
if (ENABLE_DEBUG_ENDPOINTS.value() === "true") {
  exports.hashpassword = onRequest(
    { cors: true, region: "us-central1" },
    async (req, res) => {
      try {
        const decoded = await requireFirebaseAuth(req);
        const role = getRoleFromClaims(decoded);
        if (!isSuperiorRole(role) && !isSchoolAdminRole(role) && !isRegionalAdminRole(role)) {
          return res.status(403).json({ error: "Forbidden" });
        }

        const bcrypt = require("bcrypt");
        const { password } = req.body;

        if (!password) {
          return res.status(400).json({ error: "Password is required" });
        }

        const hashedPassword = await bcrypt.hash(password, 12);
        return res.status(200).json({ hashedPassword });
      } catch (error) {
        console.error("Error hashing password:", error);
        return res.status(error.statusCode || 500).json({ error: "Failed to hash password" });
      }
    }
  );
}

// LEGACY ONLY: custom student login endpoint.
// Not deployed unless ENABLE_LEGACY_STUDENTLOGIN=true.
if (ENABLE_LEGACY_STUDENTLOGIN.value() === "true") {
  exports.studentlogin = onRequest(
    { cors: true, region: "us-central1" },
    async (req, res) => {
      try {
        const bcrypt = require("bcrypt");
        const { credential, password, schoolId } = req.body;

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
        return res.status(500).json({
          success: false,
          error: "Authentication failed",
        });
      }
    }
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Process notifications for a single bus (called from onBusLocationUpdate)
// ═══════════════════════════════════════════════════════════════════════════
async function processNotificationsForBus(schoolId, busId, busData) {
  const db = admin.firestore();
  
  try {
    
    // Prefer schooldetails (new primary), but fallback to schools (legacy) if needed.
    let studentsRef = db.collection(`schooldetails/${schoolId}/students`);
    let studentsCollectionName = 'schooldetails';

    // Get exact stop names from RTDB (case-sensitive)
    const remainingStopNames = (busData.remainingStops || [])
      .map((s) => s?.name || s?.stopName || "")
      .filter((name) => name);
    const uniqueStopNames = Array.from(new Set(remainingStopNames));

    // Normalized stop names for matching (case-insensitive)
    const uniqueStopNamesNormalized = Array.from(
      new Set(uniqueStopNames.map((n) => (n || "").toLowerCase().trim()))
    );
    

    if (uniqueStopNames.length === 0) {
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        allStudentsNotified: true,
        noPendingStudents: true,
      });
      return;
    }

    // Simple broad query - get all students for this bus on this trip
    let snapshot = await studentsRef
      .where('assignedBusId', '==', busId)
      .where('notified', '==', false)
      .where('currentTripId', '==', busData.currentTripId)
      .get();

    if (snapshot.empty) {
      const fallbackRef = db.collection(`schools/${schoolId}/students`);
      const fallbackSnap = await fallbackRef
        .where('assignedBusId', '==', busId)
        .where('notified', '==', false)
        .where('currentTripId', '==', busData.currentTripId)
        .get();

      if (!fallbackSnap.empty) {
        studentsRef = fallbackRef;
        studentsCollectionName = 'schools';
        snapshot = fallbackSnap;
      }
    }

    

    // Route scoping (multi-route): if bus has routeRefId, only process students for that route
    const routeRefId = busData.routeRefId || busData.activeRouteRefId || null;
    const routeScopedDocs = routeRefId
      ? snapshot.docs.filter((d) => (d.data() || {}).assignedRouteId === routeRefId)
      : snapshot.docs;

    if (routeRefId) {
    }
    
    // If no students found, check what went wrong
    if (snapshot.size === 0) {
      const allBusStudents = await studentsRef
        .where('assignedBusId', '==', busId)
        .get();
      
      allBusStudents.forEach((doc) => {
        const s = doc.data();
      });
    }
    
    // Filter candidates. Prefer matching by stop name, but if student has coordinates,
    // keep them so findStopData can do location-based matching (avoids name formatting issues).
    const fetchedDocs = routeScopedDocs.filter((doc) => {
      const student = doc.data();
      const studentStopName = student.stopping || student.stopLocation?.name || "";

      const hasCoords =
        student.stopLocation &&
        student.stopLocation.latitude &&
        student.stopLocation.longitude;

      const nameMatches =
        studentStopName &&
        uniqueStopNamesNormalized.includes(
          (studentStopName || "").toLowerCase().trim()
        );

      const keep = Boolean(nameMatches || hasCoords);

      return keep;
    });
    

    if (fetchedDocs.length === 0) {
      
      // Check if trip just started (within 2 minutes) - don't flag yet
      const tripStartedAt = busData.tripStartedAt || 0;
      const timeSinceStart = (Date.now() - tripStartedAt) / 1000 / 60; // minutes
      
      if (timeSinceStart < 2) {
        return;
      }
      
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        allStudentsNotified: true,
        noPendingStudents: true,
      });
      return;
    }
    
    
    const notificationTasks = [];
    
    fetchedDocs.forEach((doc) => {
      const student = doc.data();
      const stopName = (student.stopping || student.stopLocation?.name || '').trim();

      // Hard guard: a student should be notified at most once per trip.
      // This protects against any external logic accidentally flipping `notified` back to false.
      // NOTE: Some reset flows intentionally set lastNotifiedAt=null; in that case, allow notification.
      if (
        student.lastNotifiedTripId &&
        student.lastNotifiedTripId === busData.currentTripId &&
        student.lastNotifiedAt
      ) {
        return;
      }
      
      if (!stopName || student.notificationPreferenceByTime === null || student.notificationPreferenceByTime === undefined) {
        return;
      }
      
      
      const stopData = findStopData(busData, stopName, student.stopLocation);
      
      if (!stopData) {
        return;
      }
      
      const eta = stopData.estimatedMinutesOfArrival;

      const threshold = Number(student.notificationPreferenceByTime);
      if (!Number.isFinite(threshold)) {
        return;
      }
      
      // Check if ETA is actually calculated (not null/undefined/NaN)
      if (eta === null || eta === undefined || isNaN(eta)) {
        return;
      }
      
      
      // Check if notification threshold met
      if (eta !== null && eta !== undefined && eta <= threshold) {
        
        if (!student.fcmToken) {
          return;
        }
        
        const isVoiceNotification = (student.notificationType || "").toLowerCase() === "voice notification";
        
        const lang = (student.languagePreference || "english").toLowerCase();
        const soundName = `notification_${lang}`; // e.g., "notification_english"
        
        const payload = {
          token: student.fcmToken,
          // ✅ Root-level notification field for reliable delivery
          notification: {
            title: "Bus Approaching!",
            body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
          },
          // ✅ Data field for custom handling in Flutter
          data: {
            type: "bus_arrival",
            title: "Bus Approaching!",
            body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
            studentId: doc.id,
            notificationType: isVoiceNotification ? "Voice Notification" : "Text Notification",
            selectedLanguage: lang,
            eta: eta.toString(),
            busId: busId,
            sound: soundName,
          },
          // ✅ Android-specific configuration
          android: {
            priority: "high",
            ttl: 2 * 60 * 1000,
            notification: {
              title: "Bus Approaching!",
              body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
              channel_id: `busmate_voice_${lang}`,
              // Sound is bound to channel, don't specify here
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          // ✅ iOS (APNs) specific configuration
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-expiration": "120000",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                alert: {
                  title: "Bus Approaching!",
                  body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
                },
                sound: `${soundName}.wav`,
                "content-available": 1,
                "mutable-content": 1,
                badge: 1,
                category: "BUSMATE_CATEGORY",
                "thread-id": "bus_arrival",
                "interruption-level": "time-sensitive",
              },
            },
          },
        }
        
        const tripDirection = busData.tripDirection || 'unknown';
        
        // Queue notification task with student reference
        notificationTasks.push({
          payload,
          docRef: doc.ref,
          studentName: student.name,
          studentId: doc.id,
          updateData: {
            notified: true,
            lastNotifiedTripId: busData.currentTripId,
            lastNotifiedRoute: tripDirection,
            lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        });
        
      } else {
      }
    });
    
    // Send notifications and update ONLY on success
    if (notificationTasks.length > 0) {
      
      const successfulUpdates = [];
      
      await Promise.all(notificationTasks.map(async (task) => {
        try {
          
          const sendStartTime = Date.now();
          const result = await admin.messaging().send(task.payload);
          const sendDuration = Date.now() - sendStartTime;
          
          
          // Only mark for update if notification was successfully sent
          successfulUpdates.push({
            ref: task.docRef,
            data: task.updateData,
            studentName: task.studentName
          });
        } catch (error) {
          // Dead token codes: token no longer registered (app uninstalled / reinstalled).
          // Wipe the token immediately so future GPS events skip this student entirely
          // instead of retrying a guaranteed-fail send on every notification round.
          const DEAD_TOKEN_CODES = new Set([
            'messaging/registration-token-not-registered',
            'messaging/invalid-registration-token',
            'messaging/invalid-recipient',
          ]);

          if (DEAD_TOKEN_CODES.has(error.code) || (error.errorInfo && DEAD_TOKEN_CODES.has(error.errorInfo.code))) {
            try {
              await task.docRef.update({ fcmToken: admin.firestore.FieldValue.delete() });
            } catch (cleanupErr) {
              console.error(`   ❌ Failed to clean dead token for student ${task.studentId}: ${cleanupErr.message}`);
            }
          } else {
            // Transient error (network, quota, etc.) — log for debugging but don't wipe token
            console.error(`   ❌ FCM send failed for student ${task.studentId}: [${error.code || 'UNKNOWN'}] ${error.message}`);
          }
        }
      }));
      
      // Update student records ONLY for successful notifications
      if (successfulUpdates.length > 0) {
        const batch = db.batch();
        successfulUpdates.forEach(update => {
          batch.update(update.ref, update.data);
        });
        await batch.commit();
      } else {
      }
      
      const failedCount = notificationTasks.length - successfulUpdates.length;
      if (failedCount > 0) {
      }
    }
    
  } catch (error) {
    console.error(`   ❌ Error processing notifications for bus ${busId}:`, error);
  }
}

async function maybeResetStudentsForTripServerSide(schoolId, busId, busData) {
  try {
    const tripId = busData?.currentTripId;
    if (!tripId) {
      return;
    }

    // Only reset once per trip, and only near trip start.
    // This prevents mid-trip resets (which could cause duplicate notifications).
    const tripStartedAt = Number(busData?.tripStartedAt || 0);
    const now = Date.now();
    const minutesSinceStart = tripStartedAt > 0 ? (now - tripStartedAt) / 60000 : null;
    const isNearStart = minutesSinceStart === null || (minutesSinceStart >= 0 && minutesSinceStart <= 5);

    if (!isNearStart) {
      return;
    }

    // IMPORTANT: Read the marker from RTDB to avoid using stale busData.
    // (busData comes from event payload and may not include latest marker fields.)
    const markerSnap = await admin
      .database()
      .ref(`bus_locations/${schoolId}/${busId}/studentsResetTripId`)
      .once('value');
    const markerTripId = markerSnap.val();
    if (markerTripId === tripId) {
      return;
    }

    const db = admin.firestore();

    // Prefer schooldetails; fallback to schools if this school still uses legacy structure.
    let studentsRef = db.collection(`schooldetails/${schoolId}/students`);
    let studentsCollectionName = 'schooldetails';
    let query = studentsRef.where('assignedBusId', '==', busId);

    // Multi-route buses: only reset students assigned to the active routeRefId
    const routeRefId = busData?.routeRefId || busData?.activeRouteRefId || null;
    if (routeRefId) {
      query = query.where('assignedRouteId', '==', routeRefId);
    }

    let snapshot = await query.get();

    if (snapshot.empty) {
      const fallbackRef = db.collection(`schools/${schoolId}/students`);
      let fallbackQuery = fallbackRef.where('assignedBusId', '==', busId);
      if (routeRefId) {
        fallbackQuery = fallbackQuery.where('assignedRouteId', '==', routeRefId);
      }
      const fallbackSnap = await fallbackQuery.get();
      if (!fallbackSnap.empty) {
        studentsRef = fallbackRef;
        studentsCollectionName = 'schools';
        query = fallbackQuery;
        snapshot = fallbackSnap;
      }
    }
    if (snapshot.empty) {
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        studentsResetTripId: tripId,
        studentsResetAt: now,
        studentsResetCount: 0,
        studentsResetSource: 'functions',
        studentsResetCollection: studentsCollectionName,
      });
      return;
    }

    // Batch in chunks to avoid 500-write limit
    const docs = snapshot.docs;
    let updated = 0;

    for (let i = 0; i < docs.length; i += 450) {
      const chunk = docs.slice(i, i + 450);
      const batch = db.batch();
      for (const doc of chunk) {
        batch.update(doc.ref, {
          notified: false,
          currentTripId: tripId,
          tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastNotifiedAt: null,
          lastNotifiedTripId: null,
        });
      }
      await batch.commit();
      updated += chunk.length;
    }

    await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
      studentsResetTripId: tripId,
      studentsResetAt: now,
      studentsResetCount: updated,
      studentsResetSource: 'functions',
      studentsResetCollection: studentsCollectionName,
    });

  } catch (e) {
    console.error(`   ❌ [Trip Reset] Failed resetting students for bus ${busId}:`, e);
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
    timeoutSeconds: 30,
    cpu: 0.25,
    maxInstances: 80,
    secrets: [OLA_MAPS_API_KEY],
  },
  async (event) => {
    const schoolId = event.params.schoolId;
    const busId = event.params.busId;
    const gpsData = event.data.after.val();

    if (!gpsData) {
      return;
    }


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
        return;
      }
      
      // Update lastUpdateTimestamp to track GPS freshness (only on real GPS updates)
      const now = Date.now();
      await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
        lastUpdateTimestamp: now,
      });

      // ✅ Trip-start reset (server-side): ensure students are eligible for notifications.
      // Runs only when tripId changes or when a reset is missing near trip start.
      if (busData.currentTripId) {
        const prevTripId = previousData ? previousData.currentTripId : null;
        const tripChanged = !prevTripId || prevTripId !== busData.currentTripId;
        const needsReset = busData.studentsResetTripId !== busData.currentTripId;
        const tripStartedAt = Number(busData.tripStartedAt || 0);
        const minutesSinceStart = tripStartedAt > 0 ? (now - tripStartedAt) / 60000 : null;
        const nearStart = minutesSinceStart === null || (minutesSinceStart >= 0 && minutesSinceStart <= 5);

        if (nearStart && (tripChanged || needsReset)) {
          await maybeResetStudentsForTripServerSide(schoolId, busId, busData);
        }
      }

      // Check if bus is active
      if (!busData.isActive) {
        return;
      }

      // Skip ONLY if explicitly set to false (undefined/null means we should check time or allow)
      if (busData.isWithinTripWindow === false) {
        return;
      }
      
      // If isWithinTripWindow is undefined, log warning but continue (backward compatibility)
      if (busData.isWithinTripWindow === undefined || busData.isWithinTripWindow === null) {
      }
      
      // 🚦 TIME-BASED ROUTE ACTIVATION: Determine which route should be active
      const activeRouteInfo = await determineActiveRoute(schoolId, busId, busData);
      
      if (!activeRouteInfo || !activeRouteInfo.routeId) {
        return;
      }
      
      
      // Check if ETAs need initial calculation (first GPS update after trip start)
      const needsInitialETA = !busData.lastETACalculation || busData.lastETACalculation === 0;
      
      // 🔧 INITIALIZATION: If remainingStops is empty/missing, populate from route schedule
      const needsStopsInitialization = !busData.remainingStops || 
                                        busData.remainingStops.length === 0 || 
                                        busData.remainingStops.some(s => !s.name || s.name.match(/^Stop\d+$/));
      
      if (needsStopsInitialization) {
        await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          routeName: activeRouteInfo.routeName,
          activeRouteRefId: activeRouteInfo.routeRefId || null,
          routeRefId: activeRouteInfo.routeRefId || null,
          routeRefName: activeRouteInfo.routeRefName || null,
          remainingStops: activeRouteInfo.stoppings,
          totalStops: activeRouteInfo.stoppings.length,
          allStudentsNotified: false,  // Reset flag for new trip
          noPendingStudents: false,    // Reset flag for new trip
        });
        
        // Force initial ETA calculation with proper stops
        await calculateAndUpdateETAs(schoolId, busId, gpsData, {
          ...busData,
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          activeRouteRefId: activeRouteInfo.routeRefId || null,
          routeRefId: activeRouteInfo.routeRefId || null,
          routeRefName: activeRouteInfo.routeRefName || null,
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
          activeRouteRefId: activeRouteInfo.routeRefId || null,
          routeRefId: activeRouteInfo.routeRefId || null,
          routeRefName: activeRouteInfo.routeRefName || null,
          remainingStops: activeRouteInfo.stoppings || busData.remainingStops,
          allStudentsNotified: false,  // Reset flag for route change
          noPendingStudents: false,    // Reset flag for route change
        });
        
        // Force ETA recalculation when route changes
        await calculateAndUpdateETAs(schoolId, busId, gpsData, {
          ...busData,
          activeRouteId: activeRouteInfo.routeId,
          tripDirection: activeRouteInfo.direction,
          activeRouteRefId: activeRouteInfo.routeRefId || null,
          routeRefId: activeRouteInfo.routeRefId || null,
          routeRefName: activeRouteInfo.routeRefName || null,
          remainingStops: activeRouteInfo.stoppings || busData.remainingStops,
        });
        return;
      }
      
      // Calculate ETAs on first GPS update (works for both driver app AND web simulator)
      if (needsInitialETA) {
        await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
        
        // CRITICAL: Re-read bus data after ETA calculation to get updated ETAs
        const updatedSnapshot = await admin.database().ref(`bus_locations/${schoolId}/${busId}`).once('value');
        busData = updatedSnapshot.val() || busData;
      }
      
      // ⏰ OLA MAPS API RECALCULATION: Every 3 minutes for accurate traffic-aware ETAs
      // Use SEPARATE timestamps: lastOlaAPICall for API calls, lastETAUpdate for decrements
      const lastOlaAPICall = busData.lastOlaAPICall || 0;
      const lastETAUpdate = busData.lastETAUpdate || 0;
      const timeSinceLastAPICall = (now - lastOlaAPICall) / 1000 / 60; // minutes since OLA API
      const timeSinceLastUpdate = (now - lastETAUpdate) / 1000 / 60; // minutes since any ETA update
      
      let etasRecalculated = false;
      
      // ✅ Call OLA Maps API every 3 minutes if bus is active, regardless of movement
      if (timeSinceLastAPICall >= 3 || lastOlaAPICall === 0) {
        
        await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
        
        // CRITICAL: Re-read bus data after ETA calculation to get updated ETAs
        const updatedSnapshot = await admin.database().ref(`bus_locations/${schoolId}/${busId}`).once('value');
        busData = updatedSnapshot.val() || busData;
        
        etasRecalculated = true;
      } else {

        // IMPORTANT:
        // Do NOT decrement ETAs here.
        // Decrement happens in manageBusNotifications (scheduled every 1 minute),
        // which works even when coordinates don't change and prevents double-decrement.
      }
      
      // 🚏 INSTANT STOP DETECTION: Check if bus passed any stops (runs on every GPS update!)
      // CRITICAL: For both PICKUP and DROP, stops are in traversal order in remainingStops array.
      // PICKUP: [Stop1, Stop2, Stop3, Stop4, Stop5] - traverse start to end
      // DROP: [Stop5, Stop4, Stop3, Stop2, Stop1] - also traverse start to end (already reversed in startTrip)
      // Therefore, ALWAYS remove from the START (index 0) for both directions!
      if (busData.remainingStops && busData.remainingStops.length > 0) {
        const STOP_PROXIMITY_THRESHOLD = 200; // meters
        const busLocation = { lat: busData.latitude, lng: busData.longitude };
        const tripDirection = busData.tripDirection || 'pickup';
        let stopsRemoved = 0;
        
        // UNIFIED LOGIC: Check stops from START of array for both PICKUP and DROP
        const firstStop = busData.remainingStops[0];
        if (firstStop && firstStop.latitude && firstStop.longitude) {
          const distanceToFirst = calculateDistance(busLocation, { lat: firstStop.latitude, lng: firstStop.longitude });
          
          if (distanceToFirst <= STOP_PROXIMITY_THRESHOLD) {
            busData.remainingStops.shift(); // Remove from start
            stopsRemoved = 1;
          } else {
            // Check if bus skipped stops and is near a later stop
            for (let i = 1; i < Math.min(3, busData.remainingStops.length); i++) {
              const stop = busData.remainingStops[i];
              if (!stop || !stop.latitude || !stop.longitude) continue;
              
              const distance = calculateDistance(busLocation, { lat: stop.latitude, lng: stop.longitude });
              
              if (distance <= STOP_PROXIMITY_THRESHOLD) {
                // Remove all skipped stops plus current stop from START
                for (let j = 0; j <= i; j++) {
                  const removed = busData.remainingStops.shift();
                }
                stopsRemoved = i + 1;
                break;
              }
            }
          }
        }
        
        if (stopsRemoved > 0) {
          const newStopsPassedCount = (busData.stopsPassedCount || 0) + stopsRemoved;
          
          // Update immediately
          await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
            remainingStops: busData.remainingStops,
            stopsPassedCount: newStopsPassedCount,
          });
          
          // If all stops completed, mark trip as inactive
          if (busData.remainingStops.length === 0) {
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
      
      if (busData.currentTripId && busData.remainingStops && busData.remainingStops.length > 0) {
        // 💡 OPTIMIZATION (Idea 7): Skip when all students already notified or none pending
        if (busData.allStudentsNotified === true || busData.noPendingStudents === true) {
        } else {
          await processNotificationsForBus(schoolId, busId, busData);
        }
      } else {
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
    const istOffset = 5.5 * 60 * 60 * 1000;
    const nowIST = new Date(nowUTC.getTime() + istOffset);

    const currentTime = `${nowIST.getHours().toString().padStart(2, '0')}:${nowIST.getMinutes().toString().padStart(2, '0')}`;
    const currentDay = nowIST.getDay() || 7; // Sunday = 7
    const currentDayName = nowIST.toLocaleDateString('en-US', { weekday: 'long' });

    // ✅ FAST PATH: If busData already has a valid cached route, return immediately
    // WITHOUT making any RTDB read. Only fall through (and read RTDB) when:
    //   - No activeRouteId set yet, OR
    //   - Schedule times not cached, OR
    //   - Current time is outside the cached time window (trip ended / new trip)
    //   - More than 5 minutes since last resolution (safety refresh every 5 min)
    if (busData.activeRouteId && busData.scheduleStartTime && busData.scheduleEndTime) {
      const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
      const lastResolved = busData.routeLastResolved || 0;
      const cacheExpired = (Date.now() - lastResolved) > CACHE_TTL_MS;

      let isWithinWindow;
      if (busData.scheduleStartTime > busData.scheduleEndTime) {
        // Overnight schedule
        isWithinWindow = currentTime >= busData.scheduleStartTime || currentTime <= busData.scheduleEndTime;
      } else {
        isWithinWindow = currentTime >= busData.scheduleStartTime && currentTime <= busData.scheduleEndTime;
      }

      if (isWithinWindow && !cacheExpired) {
        // ⚡ Zero RTDB reads — serve entirely from busData
        return {
          routeId: busData.activeRouteId,
          routeName: busData.routeName || "Active Route",
          direction: busData.tripDirection || "unknown",
          stoppings: busData.remainingStops || [],
          routeRefId: busData.routeRefId || busData.activeRouteRefId || null,
          routeRefName: busData.routeRefName || null,
        };
      }
      // isWithinWindow=false or cache expired → fall through to re-resolve from RTDB
    }

    // 🔍 SLOW PATH: Read schedules from RTDB cache (only runs when fast path misses)
    const schedulesRef = admin.database().ref(`route_schedules_cache/${schoolId}/${busId}`);
    const schedulesSnapshot = await schedulesRef.once('value');
    const allSchedules = schedulesSnapshot.val() || {};
    
    // 🔍 SEARCH ALL SCHEDULES: Find which schedule matches current time/day
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

        const routeRefId = schedule.routeRefId || null;
        const routeRefName = schedule.routeRefName || null;
        
        // Get stops for this direction (already stored separately for pickup/drop)
        const directionStops = schedule.stops || schedule.stoppings || [];
        
        // Update RTDB if this is different from current active route,
        // and always stamp routeLastResolved so the fast path cache TTL resets.
        if (busData.activeRouteId !== routeId || busData.tripDirection !== schedule.direction) {
          const tripId = buildTripId(routeId, new Date().toISOString().split('T')[0], schedule.startTime || '00:00');

          await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
            activeRouteId: routeId,
            tripDirection: schedule.direction || 'pickup',
            routeName: schedule.routeName || 'Unknown Route',
            scheduleStartTime: schedule.startTime,
            scheduleEndTime: schedule.endTime,
            currentTripId: tripId,
            isWithinTripWindow: true,
            routeRefId: routeRefId,
            routeRefName: routeRefName,
            remainingStops: directionStops,
            allStudentsNotified: false,
            noPendingStudents: false,
            routeLastResolved: Date.now(),
          });
        } else {
          // Same route, same direction — only refresh the TTL timestamp
          await admin.database().ref(`bus_locations/${schoolId}/${busId}`).update({
            routeLastResolved: Date.now(),
          });
        }
        
        return {
          routeId: routeId,
          routeName: schedule.routeName || "Unknown Route",
          direction: schedule.direction || "unknown",
          stoppings: directionStops,
          routeRefId: routeRefId,
          routeRefName: routeRefName,
        };
      }
    }
    
    return null;
  } catch (error) {
    console.error(`   ❌ Error determining active route: ${error.message}`);
    return null;
  }
}

// Helper: Calculate and update ETAs using Ola Maps API
async function calculateAndUpdateETAs(schoolId, busId, gpsData, busData) {
  const OLA_API_KEY = getSecretValue(OLA_MAPS_API_KEY, "OLA_MAPS_API_KEY");

  if (!OLA_API_KEY) {
    console.error("❌ OLA_MAPS_API_KEY not configured. Set it via Secret Manager.");
    return;
  }

  if (!busData.remainingStops || busData.remainingStops.length === 0) {
    return;
  }

  try {
    // 🚦 Determine trip direction (pickup or drop)
    const tripDirection = busData.tripDirection || 'pickup';

    // ✅ Use remainingStops as-is (driver app already reversed them for DROP)
    // Driver app reverses stops when starting DROP trip, so remainingStops is already in travel order
    const stopsForCalculation = busData.remainingStops;
    
    
    // ✅ Use Ola Maps Directions API (POST with query params, lat,lng order)
    const origin = `${gpsData.latitude},${gpsData.longitude}`;
    const destination = `${stopsForCalculation[stopsForCalculation.length - 1].latitude},${stopsForCalculation[stopsForCalculation.length - 1].longitude}`;

    const waypoints = stopsForCalculation.length > 1
      ? stopsForCalculation
          .slice(0, -1)
          .map((stop) => `${stop.latitude},${stop.longitude}`)
          .join("|")
      : null;

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


          return {
            ...stop,
            estimatedMinutesOfArrival: etaMinutes,
            originalETA: etaMinutes, // ✅ Store original ETA from OLA Maps
            distanceMeters: legDistanceMeters, // Per-leg distance (not cumulative)
            eta: etaTimestamp,
            decremented: false, // Reset decrement flag
          };
        }

        return stop;
      });

      // ✅ Stops with ETAs are already in correct order (matching remainingStops)
      const updatedStops = stopsWithETAs;

      // Update Realtime Database with new ETAs (ONLY storage - no Firestore!)
      const now = Date.now();
      await admin
        .database()
        .ref(`bus_locations/${schoolId}/${busId}`)
        .update({
          remainingStops: updatedStops,
          lastOlaAPICall: now, // ✅ Track when OLA Maps was called
          lastETAUpdate: now, // ✅ Track when ETAs were last updated
          lastETACalculation: now, // Keep for backward compatibility
        });

    } else {
    }
    } catch (error) {
    console.error(`❌ Error calling Ola Maps API: ${error.message}`);
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Data:`, error.response.data);
    }
    
    // FALLBACK: Calculate ETAs using distance and average speed
    const AVERAGE_SPEED_MPS = 8.33; // 30 km/h = 8.33 m/s (realistic city speed)
    
    // ✅ Use remainingStops as-is (already in travel order)
    const stopsForCalculation = busData.remainingStops;
    
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
      
      
      // Update previous location for next iteration
      previousLocation = { lat: stop.latitude, lng: stop.longitude };
      
      return {
        ...stop,
        estimatedMinutesOfArrival: etaMinutes,
        originalETA: etaMinutes, // ✅ Store original ETA
        distanceMeters: legDistance,
        eta: new Date(Date.now() + cumulativeDuration * 1000).toISOString(),
        decremented: false, // Reset decrement flag
      };
    });
    
    // ✅ Stops with ETAs are already in correct order
    const updatedStops = stopsWithETAs;
    
    // Update Realtime Database with fallback ETAs (ONLY storage - no Firestore!)
    const now = Date.now();
    await admin
      .database()
      .ref(`bus_locations/${schoolId}/${busId}`)
      .update({
        remainingStops: updatedStops,
        lastOlaAPICall: now, // ✅ Track when ETA was calculated
        lastETAUpdate: now, // ✅ Track when ETAs were last updated
        lastETACalculation: now, // Keep for backward compatibility
        etaCalculationMethod: 'fallback_distance',
      });
    
  }
}

// Manual test endpoint to trigger notification logic (DEBUG ONLY)
if (ENABLE_DEBUG_ENDPOINTS.value() === "true") {
exports.testNotifications = onRequest(async (req, res) => {
  
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
    
    
    if (studentsSnapshot.empty) {
      return res.json({ success: false, message: "No students found" });
    }
    
    const studentsByBus = new Map();
    
    studentsSnapshot.docs.forEach(doc => {
      const student = doc.data();
      const studentId = doc.id;
      const studentDocRef = doc.ref;
      const stopName = (student.stopping || student.stopLocation?.name || '').trim();
      
      
      if (!student.assignedBusId || !stopName || !student.notificationPreferenceByTime) {
        return;
      }

      const threshold = Number(student.notificationPreferenceByTime);
      if (!Number.isFinite(threshold)) {
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
    
    
    const notifications = [];
    const results = [];
    
    for (const [busId, students] of studentsByBus) {
      
      const busSnapshot = await rtdb.ref(`bus_locations/${students[0].schoolId}/${busId}`).once('value');
      const busData = busSnapshot.val();
      
      if (!busData || !busData.isActive) {
        results.push({ busId, status: 'inactive', students: students.length });
        continue;
      }
      
      
      for (const student of students) {
        const stopName = student.resolvedStopName;
        const stopData = findStopData(busData, stopName, student.stopLocation);

        if (!stopData || stopData.estimatedMinutesOfArrival === null || stopData.estimatedMinutesOfArrival === undefined) {
          results.push({ 
            studentId: student.studentId, 
            status: 'no_eta', 
            stopName,
            availableStops: busData.remainingStops?.map(s => s.name) || []
          });
          continue;
        }
        
        const eta = stopData.estimatedMinutesOfArrival;
        const threshold = Number(student.notificationPreferenceByTime);
        
        
        if (eta !== null && eta !== undefined && Number.isFinite(threshold) && eta <= threshold) {
          
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
            threshold
          });
        } else {
          results.push({ 
            studentId: student.studentId, 
            status: 'eta_not_met', 
            eta,
            threshold
          });
        }
      }
    }
    
    
    const sendResults = [];
    for (const payload of notifications) {
      try {
        const result = await admin.messaging().send(payload);
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
}

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
    daysOfWeek: Array.isArray(scheduleData.daysOfWeek) && scheduleData.daysOfWeek.length > 0 ? scheduleData.daysOfWeek : [1, 2, 3, 4, 5], // Default Mon-Fri if not configured
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
// 🔧 UTILITY: Add missing stoppingLower field to all students (DEBUG ONLY)
if (ENABLE_DEBUG_ENDPOINTS.value() === "true") {
exports.addStoppingLowerField = onRequest(
  { cors: true, region: "us-central1" },
  async (req, res) => {
    try {
      const decoded = await requireFirebaseAuth(req);
      if (!isSuperiorRole(getRoleFromClaims(decoded))) {
        return res.status(403).json({ success: false, error: "Forbidden" });
      }

      const db = admin.firestore();
      
      // Get all schools
      const schoolsSnapshot = await db.collection('schooldetails').get();
      
      let totalUpdated = 0;
      let totalSkipped = 0;
      
      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;
        
        // Get all students in this school
        const studentsSnapshot = await db
          .collection(`schooldetails/${schoolId}/students`)
          .get();
        
        
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
            batchCount = 0;
          }
        }
        
        // Commit remaining updates
        if (batchCount > 0) {
          await batch.commit();
        }
      }  
      
      
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
}
