const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const nodemailer = require('nodemailer');

admin.initializeApp();

// Optimized batch notification processing
exports.sendBusArrivalNotifications = onSchedule(
  {
    schedule: "every 2 minutes", // Reduced frequency for cost optimization
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
      // Also check for stale GPS data and mark buses inactive if no update for 2+ minutes
      const activeBuses = [];
      const now = Date.now();
      const twoMinutesAgo = now - (2 * 60 * 1000);
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
            
            if (lastUpdate < twoMinutesAgo) {
              const minutesSinceUpdate = Math.floor((now - lastUpdate) / (60 * 1000));
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
            } else {
              activeBuses.push({ schoolId, busId, busData });
              console.log(`✅ Found active bus: ${busId} in school ${schoolId}`);
            }
          }
        }
      }
      
      if (staleDataCount > 0) {
        console.log(`🔴 Deactivated ${staleDataCount} buses due to stale GPS data`);
      }
      
      if (activeBuses.length === 0) {
        console.log("📭 No active buses found - skipping notification check");
        return;
      }
      
      console.log(`🚌 Found ${activeBuses.length} active buses`);
      
      // STEP 2: Query ONLY students with notified=false and fcmToken (no composite index needed)
      console.log(`🔍 Querying students with notified=false...`);
      
      const studentsSnapshot = await db
        .collectionGroup("students")
        .where("notified", "==", false)
        .where("fcmToken", "!=", null)
        .get();
      
      console.log(`📋 Found ${studentsSnapshot.size} unnotified students total`);
      
      // STEP 3: Filter students to only those on active buses
      const activeBusIds = new Set(activeBuses.map(b => b.busId));
      const studentsByBus = new Map();
      let totalStudentsQueried = 0;
      
      studentsSnapshot.docs.forEach(doc => {
        const student = doc.data();
        const studentId = doc.id;
        const studentDocRef = doc.ref;
        const stopName = (student.stopping || student.stopLocation?.name || '').trim();
        
        // Only process students on active buses
        if (!activeBusIds.has(student.assignedBusId)) {
          console.log(`⏭️ Student ${studentId} is on inactive bus ${student.assignedBusId}, skipping`);
          return;
        }
        
        console.log(
          `🔍 Student ${studentId} (${student.name || 'Unknown'}): ` +
          `assignedBusId=${student.assignedBusId}, ` +
          `stopping="${stopName || 'MISSING'}", ` +
          `notificationPreference=${student.notificationPreferenceByTime || 'MISSING'}`
        );
        
        if (!student.assignedBusId || !stopName || !student.notificationPreferenceByTime) {
          console.log(`⚠️ SKIPPED student ${studentId} - Missing required fields`);
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
        totalStudentsQueried++;
      });
      
      console.log(`✅ Total students on active buses: ${totalStudentsQueried}`);
      
      if (totalStudentsQueried === 0) {
        console.log("📭 No students to process for notifications");
        return;
      }

      // STEP 3: Process each active bus with its students
      const notifications = [];
      const updates = [];
      
      console.log(`📦 Processing ${studentsByBus.size} buses with assigned students`);
      
      for (const activeBus of activeBuses) {
        const { schoolId, busId, busData } = activeBus;
        const students = studentsByBus.get(busId);
        
        if (!students || students.length === 0) {
          console.log(`⏭️ Bus ${busId} has no students awaiting notifications`);
          continue;
        }
        
        try {
          console.log(`🚌 Processing bus ${busId} with ${students.length} students`);
          
          console.log(`📊 Bus data:`, JSON.stringify({
            isActive: busData.isActive,
            activeRouteId: busData.activeRouteId,
            remainingStopsCount: busData.remainingStops?.length || 0,
            remainingStopsNames: busData.remainingStops?.map(s => s.name) || []
          }));
          
          console.log(`✅ Bus ${busId} is ACTIVE with ${busData.remainingStops?.length || 0} remaining stops`);

          // Process all students for this bus
          for (const student of students) {
            const stopName = student.resolvedStopName || student.stopping || student.stopLocation?.name;
            
            console.log(`👤 Checking student ${student.name} (${student.studentId}) - Stop: "${stopName}"`);
            
            const stopData = findStopData(busData, stopName, student.stopLocation);
            
            if (!stopData || !stopData.eta) {
              console.log(
                `❌ NO ETA DATA for ${student.name} at "${stopName}". ` +
                `Available stops: [${(busData.remainingStops || []).map((s) => `"${s.name}"`).join(', ')}]`
              );
              continue;
            }
            
            console.log(`📊 Found stop "${stopName}" - ETA: ${stopData.estimatedMinutesOfArrival} min, Preference: ${student.notificationPreferenceByTime} min`);
            
            const eta = stopData.estimatedMinutesOfArrival;
            
            if (eta !== null && eta <= student.notificationPreferenceByTime) {
              console.log(`🎯 ETA THRESHOLD MET! ${eta.toFixed(1)} min <= ${student.notificationPreferenceByTime} min`);
              
              // Check if parent should be notified (prevent duplicates on ETA recalculation)
              const shouldNotify = checkShouldNotifyParent(
                busData,
                stopName,
                stopData.eta
              );
              
              if (!shouldNotify) {
                console.log(`⏭️ DUPLICATE SKIP for ${student.name} - already notified for this ETA`);
                continue;
              }
              
              console.log(`🚍 QUEUING NOTIFICATION for ${student.name} (${student.studentId}) - ETA: ${eta.toFixed(0)} min, FCM: ${student.fcmToken ? 'Valid' : 'MISSING'}`);

              const isVoiceNotification = (student.notificationType || "").toLowerCase() === "voice notification";

              // Create notification payload
              const payload = {
                notification: {
                  title: "Bus Approaching!",
                  body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
                },
                android: {
                  priority: "high",
                  ttl: 2 * 60 * 1000, // 2 minutes TTL
                  notification: {
                    channelId: "busmate",
                    sound: isVoiceNotification ? getSoundName(student.languagePreference) : "default",
                    visibility: "public",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    defaultVibrateTimings: true,
                    defaultLightSettings: true,
                  },
                },
                apns: {
                  headers: {
                    "apns-priority": "10",
                    "apns-expiration": "120000", // 2 minutes
                  },
                  payload: {
                    aps: {
                      alert: {
                        title: "Bus Approaching!",
                        body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
                      },
                      sound: isVoiceNotification ? `${getSoundName(student.languagePreference)}.wav` : "default",
                      badge: 1,
                      contentAvailable: true,
                      mutableContent: true,
                    },
                  },
                },
                data: {
                  type: "bus_arrival",
                  title: "Bus Approaching!",
                  body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
                  studentId: student.studentId,
                  notificationType: isVoiceNotification ? "Voice Notification" : "Text Notification",
                  selectedLanguage: student.languagePreference || "english",
                  eta: eta.toString(),
                  busId: busId,
                },
                token: student.fcmToken,
              };

              notifications.push(payload);
              
              // Queue database update - track which route student was notified on
              // This allows resetting notifications when route direction changes (pickup ↔ drop)
              const tripDirection = busData.tripDirection || busData.activeRoute || 'unknown';
              updates.push({
                ref: student.studentDocRef, // Use stored Firestore reference
                data: { 
                  notified: true,
                  lastNotifiedRoute: tripDirection, // Track pickup vs drop
                  lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                }
              });
              
            } else {
              console.log(`⏸️ ETA not met for ${student.name}: ${eta?.toFixed(1) || 'N/A'} min > ${student.notificationPreferenceByTime} min`);
            }
          }
        } catch (busError) {
          console.error(`❌ Error processing bus ${busId}:`, busError);
        }
      }

      if (notifications.length > 0) {
        console.log(`📤 Sending ${notifications.length} notifications in batch`);
        console.log(`📋 Notification payloads:`, JSON.stringify(notifications.map(n => ({
          studentId: n.data?.studentId,
          eta: n.data?.eta,
          token: n.token?.substring(0, 20) + '...'
        }))));
        
        try {

          const batchSize = 10;
          for (let i = 0; i < notifications.length; i += batchSize) {
            const batch = notifications.slice(i, i + batchSize);
            await Promise.all(batch.map(async (payload) => {
              try {
                console.log(`🚀 Attempting to send to ${payload.data?.studentId}...`);
                const result = await admin.messaging().send(payload);
                console.log(`✅ Sent successfully! Message ID: ${result} - Student: ${payload.data?.studentId} - ETA: ${payload.data?.eta} min`);
              } catch (msgError) {
                console.error(`❌ FCM send failed for ${payload.data?.studentId}:`, msgError.message, msgError.code);
              }
            }));
          }
          
          console.log(`✅ Batch send completed for ${notifications.length} notifications`);
        } catch (error) {
          console.error(`❌ Error in notification batch send:`, error);
        }
      } else {
        console.log(`📭 No notifications to send (notifications array is empty)`);
      }
      
      if (updates.length > 0) {
        console.log(`💾 Performing ${updates.length} database updates in batch`);
        
        const batch = db.batch();
        updates.forEach(update => {
          batch.update(update.ref, update.data);
        });
        
        try {
          await batch.commit();
          console.log(`✅ Successfully updated ${updates.length} documents`);
        } catch (error) {
          console.error(`❌ Error updating database:`, error);
        }
      }

      const endTime = Date.now();
      const duration = endTime - startTime;
      console.log(`⏱️ Notification job completed in ${duration}ms`);
      
    } catch (error) {
      console.error("❌ Error in sendBusArrivalNotifications:", error);
    }
  }
);

function findStopData(busStatusData, studentLocationName, studentLocation) {
  // Check if remainingStops exists (bus may have completed route)
  if (!busStatusData.remainingStops || busStatusData.remainingStops.length === 0) {
    console.log(`⚠️ No remaining stops for bus - route may be completed`);
    return null;
  }

  // First try to match by name
  let stop = busStatusData.remainingStops.find(
    (s) => s.name === studentLocationName
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
  if (stop.eta) {
    // eta is stored as ISO string like "2025-12-08T07:57:15.129Z"
    etaDate = new Date(stop.eta);
  } else if (stop.estimatedTimeOfArrival) {
    // Legacy format with _seconds timestamp
    etaDate = stop.estimatedTimeOfArrival._seconds 
      ? new Date(stop.estimatedTimeOfArrival._seconds * 1000)
      : new Date(stop.estimatedTimeOfArrival);
  }
  
  return {
    name: stop.name,
    estimatedMinutesOfArrival: stop.estimatedMinutesOfArrival,
    eta: etaDate,
  };
}

function getETAInMinutes(data, studentLocationName) {
  const stopData = findStopData(data, studentLocationName);
  if (!stopData) return null;
  return stopData.estimatedMinutesOfArrival;
}

/// Check if parent should be notified for this stop
/// Prevents duplicate notifications when ETA is recalculated
function checkShouldNotifyParent(busStatusData, stopName, newETA) {
  // If no tracking data exists, allow notification
  if (!busStatusData.lastNotifiedETAs) {
    return true;
  }
  
  // Check if we've notified for this stop before
  const lastNotified = busStatusData.lastNotifiedETAs[stopName];
  if (lastNotified) {
    const lastNotifiedDate = lastNotified._seconds 
      ? new Date(lastNotified._seconds * 1000)
      : new Date(lastNotified);
    
    const timeDifferenceMinutes = Math.abs(
      (newETA.getTime() - lastNotifiedDate.getTime()) / (1000 * 60)
    );
    
    // Only notify again if ETA changed by more than 2 minutes
    if (timeDifferenceMinutes < 2) {
      return false; // Don't notify - ETA hasn't changed significantly
    }
    
    console.log(`🔔 ETA changed by ${timeDifferenceMinutes.toFixed(1)} min for ${stopName} - allowing notification`);
  }
  
  return true;
}


function getSoundName(language) {
  // Temporarily using Tamil notification for all languages
  // TODO: Replace with language-specific files later
  return "notification_tamil";
  
  // Original language mapping (disabled):
  // switch ((language || "").toLowerCase()) {
  //   case "english":
  //     return "notification_english";
  //   case "hindi":
  //     return "notification_hindi";
  //   case "tamil":
  //     return "notification_tamil";
  //   case "telugu":
  //     return "notification_telugu";
  //   case "kannada":
  //     return "notification_kannada";
  //   case "malayalam":
  //     return "notification_malayalam";
  //   default:
  //     return "notification_english";
  // }
}




// notify status reset every day
// IMPROVED: Reset notified status when trip schedule starts (not midnight)
// This ensures notifications work correctly for both pickup and drop trips
exports.resetStudentNotifiedStatus = onSchedule("*/5 * * * *", async (event) => {
  // Run every 5 minutes to manage trip lifecycle (start/end)
  // ALL times come from route_schedules - NO hardcoded values!
  const db = admin.firestore();
  const rtdb = admin.database();

  try {
    console.log(`🔄 Checking trip schedules for notification management...`);
    
    // Get all buses from Realtime Database (including inactive ones)
    const busLocationsSnapshot = await rtdb.ref('bus_locations').once('value');
    const busLocations = busLocationsSnapshot.val();
    
    if (!busLocations) {
      console.log("📭 No bus locations found");
      return;
    }
    
    const now = new Date();
    const currentTime = now.toTimeString().substring(0, 5); // "HH:MM"
    const currentDay = now.toLocaleDateString('en-US', { weekday: 'long' });
    
    console.log(`📅 Current: ${currentDay} ${currentTime}`);
    
    let resetCount = 0;
    let forcedCount = 0;
    let busesActivated = 0;
    let busesDeactivated = 0;
    
    // Check each school's buses
    for (const schoolId of Object.keys(busLocations)) {
      const schoolBuses = busLocations[schoolId];
      
      for (const busId of Object.keys(schoolBuses)) {
        const busData = schoolBuses[busId];
        
        // Get ALL route schedules for this bus (pickup + drop)
        const schedulesSnapshot = await db
          .collection('schools')
          .doc(schoolId)
          .collection('route_schedules')
          .where('busId', '==', busId)
          .where('isActive', '==', true)
          .get();
        
        if (schedulesSnapshot.empty) {
          continue;
        }
        
        // Check each schedule (pickup and drop routes)
        for (const routeDoc of schedulesSnapshot.docs) {
          const schedule = routeDoc.data();
          const routeId = routeDoc.id;
          
          // Check if it's a scheduled day
          if (!schedule.daysOfWeek || !schedule.daysOfWeek.includes(currentDay)) {
            continue;
          }
          
          const startTime = schedule.startTime || "00:00";
          const endTime = schedule.endTime || "23:59";
          const direction = schedule.direction || 'pickup';
          
          const startDiff = calculateTimeDifference(currentTime, startTime);
          const endDiff = calculateTimeDifference(currentTime, endTime);
          
          // 🚀 TRIP START: Within 5 minutes of start time
          if (startDiff >= 0 && startDiff <= 5) {
            console.log(`   🚀 Trip starting: ${schedule.routeName} (${direction}) at ${startTime}`);
            
            // Query students on this bus using collectionGroup
            const studentsSnapshot = await db
              .collectionGroup('students')
              .where('assignedBusId', '==', busId)
              .where('schoolId', '==', schoolId)
              .get();
            
            if (!studentsSnapshot.empty) {
              const batch = db.batch();
              let batchResetCount = 0;
              
              studentsSnapshot.forEach((doc) => {
                const student = doc.data();
                
                // Reset notification status for this trip
                // Allow re-notification even if notified on previous trip
                if (student.notified === true && student.lastNotifiedRoute !== direction) {
                  console.log(`      ✅ Resetting ${student.name} for ${direction} trip`);
                  batch.update(doc.ref, {
                    notified: false,
                    lastNotifiedRoute: null,
                    tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                  batchResetCount++;
                }
              });
              
              if (batchResetCount > 0) {
                await batch.commit();
                resetCount += batchResetCount;
                console.log(`      📊 Reset ${batchResetCount} students for ${direction} trip`);
              }
            }
            
            // Activate bus if not already active with this route
            if (!busData.isActive || busData.activeRouteId !== routeId || busData.tripDirection !== direction) {
              console.log(`      🟢 Activating bus ${busId} for ${direction} route`);
              await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                isActive: true,
                activeRouteId: routeId,
                tripDirection: direction,
                routeName: schedule.routeName,
                tripStartedAt: Date.now(),
                activationReason: 'Trip schedule started',
                scheduleStartTime: startTime,
                scheduleEndTime: endTime,
              });
              busesActivated++;
            }
          }
          
          // 🏁 TRIP END: Within 5 minutes of end time
          if (endDiff >= 0 && endDiff <= 5) {
            console.log(`   🏁 Trip ending: ${schedule.routeName} (${direction}) at ${endTime}`);
            
            // Force notified=true for students who weren't notified during trip
            const unnotifiedSnapshot = await db
              .collectionGroup('students')
              .where('assignedBusId', '==', busId)
              .where('schoolId', '==', schoolId)
              .where('notified', '==', false)
              .get();
            
            if (!unnotifiedSnapshot.empty) {
              const batch = db.batch();
              let batchForcedCount = 0;
              
              unnotifiedSnapshot.forEach((doc) => {
                const student = doc.data();
                console.log(`      🔒 Force notified=true for ${student.name} (trip ended)`);
                batch.update(doc.ref, {
                  notified: true,
                  lastNotifiedRoute: direction,
                  lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                  notifiedByTripEnd: true, // Flag to indicate forced notification
                  tripEndReason: 'Schedule ended - student not notified during trip',
                });
                batchForcedCount++;
              });
              
              if (batchForcedCount > 0) {
                await batch.commit();
                forcedCount += batchForcedCount;
                console.log(`      📊 Forced ${batchForcedCount} students to notified=true`);
              }
            }
            
            // Deactivate bus if this route is active
            if (busData.isActive && busData.activeRouteId === routeId) {
              console.log(`      🔴 Deactivating bus ${busId} for ${direction} route`);
              await rtdb.ref(`bus_locations/${schoolId}/${busId}`).update({
                isActive: false,
                tripEndedAt: Date.now(),
                deactivationReason: 'Trip schedule ended',
                lastActiveRoute: routeId,
                lastTripDirection: direction,
              });
              busesDeactivated++;
            }
          }
        }
      }
    }
    
    // Summary log
    if (resetCount > 0 || forcedCount > 0 || busesActivated > 0 || busesDeactivated > 0) {
      console.log(`✅ Trip management complete:`);
      console.log(`   📊 Students reset: ${resetCount}`);
      console.log(`   📊 Students forced: ${forcedCount}`);
      console.log(`   📊 Buses activated: ${busesActivated}`);
      console.log(`   📊 Buses deactivated: ${busesDeactivated}`);
    } else {
      console.log(`📋 No trip transitions at this time`);
    }
  } catch (error) {
    console.error("❌ Error in trip schedule management:", error);
  }
});

// Helper: Calculate time difference in minutes
function calculateTimeDifference(currentTime, targetTime) {
  const [currentHour, currentMin] = currentTime.split(':').map(Number);
  const [targetHour, targetMin] = targetTime.split(':').map(Number);
  
  const currentMinutes = currentHour * 60 + currentMin;
  const targetMinutes = targetHour * 60 + targetMin;
  
  return currentMinutes - targetMinutes; // Positive if current is after target
}

// NEW: Reset notifications when route direction changes (pickup ↔ drop)
// This allows parents to receive notifications for BOTH trips in a single day
// REMOVED - Now handled by trip schedule-based reset above
// The resetStudentNotifiedStatus function handles both trip start and direction changes

// NOTE: Stale GPS data checking is now integrated into sendBusArrivalNotifications
// No separate scheduled function needed - runs every 2 minutes with notification checks



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
// UNIFIED GPS ARCHITECTURE - Central ETA Calculator
// ═══════════════════════════════════════════════════════════════════════════
// This function triggers whenever GPS data is written to Realtime Database
// from either Driver Phone or Hardware GPS device. It centralizes all Ola Maps
// API calls for ETA calculation, making the system simpler and more efficient.
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
      const busData = gpsData;
      
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
        return;
      }
      
      // ⏰ TIME-BASED RECALCULATION: Update ETAs every 1 minute (TESTING MODE)
      const lastCalculation = busData.lastETACalculation || 0;
      const timeSinceLastCalc = (now - lastCalculation) / 1000 / 60; // minutes
      
      if (timeSinceLastCalc >= 1) {
        console.log(`🚀 1 minute elapsed - recalculating ETAs (${timeSinceLastCalc.toFixed(1)} min since last update)`);
        await calculateAndUpdateETAs(schoolId, busId, gpsData, busData);
      } else {
        console.log(`⏭️ Skipping ETA recalculation - only ${timeSinceLastCalc.toFixed(1)} min since last update (need 1 min)`);
      }
    } catch (error) {
      console.error(`❌ Error processing GPS update for bus ${busId}:`, error);
    }
  }
);

// Helper: Determine which route should be active (pickup or drop) based on time
async function determineActiveRoute(schoolId, busId, busData) {
  try {
    const now = new Date();
    const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    const currentDay = now.getDay() || 7; // Sunday = 7
    
    console.log(`   ⏰ Current Time: ${currentTime}, Day: ${currentDay}`);
    
    // Check if route is manually activated (but still validate time window!)
    if (busData.activeRouteId) {
      console.log(`   🎯 Checking active route: ${busData.activeRouteId}`);
      
      // Fetch route schedule to validate time window
      const routeDoc = await admin.firestore()
        .collection("schools")
        .doc(schoolId)
        .collection("route_schedules")
        .doc(busData.activeRouteId)
        .get();
      
      if (routeDoc.exists) {
        const route = routeDoc.data();
        
        // 🔒 TIME WINDOW VALIDATION: Check if current time is within schedule
        if (route.startTime && route.endTime && route.daysOfWeek) {
          const isWithinTimeWindow = currentTime >= route.startTime && currentTime <= route.endTime;
          const isDayScheduled = route.daysOfWeek.includes(currentDay);
          
          if (!isWithinTimeWindow || !isDayScheduled) {
            console.log(`   🔒 GPS BLOCKED: Outside time window`);
            console.log(`      Schedule: ${route.startTime} - ${route.endTime}, Days: ${route.daysOfWeek}`);
            console.log(`      Current: ${currentTime}, Day: ${currentDay}`);
            console.log(`      Time match: ${isWithinTimeWindow}, Day match: ${isDayScheduled}`);
            
            // Mark bus as inactive (outside schedule window)
            await admin.database()
              .ref(`bus_locations/${schoolId}/${busId}`)
              .update({
                isActive: false,
                deactivationReason: 'Outside route schedule time window',
                lastDeactivatedAt: Date.now(),
              });
            
            return null; // Block GPS processing
          }
          
          console.log(`   ✅ Route within time window - allowing GPS processing`);
        }
        
        return {
          routeId: busData.activeRouteId,
          routeName: route.routeName || "Unknown Route",
          direction: route.direction || "unknown",
          stoppings: route.stops || route.stoppings || [],
        };
      }
    }
    
    // Auto-activation based on time - Query all schedules for this bus
    console.log(`   🔍 Checking for auto-activatable routes...`);
    
    // Get all route schedules for this bus
    const schedulesSnapshot = await admin.firestore()
      .collection("schools")
      .doc(schoolId)
      .collection("route_schedules")
      .where("busId", "==", busId)
      .where("isActive", "==", true)
      .get();
    
    if (schedulesSnapshot.empty) {
      console.log(`   ⚠️ No active route schedules found for bus ${busId}`);
      return null;
    }
    
    // Check each schedule to find one that should be active now
    for (const doc of schedulesSnapshot.docs) {
      const schedule = doc.data();
      
      console.log(`   📋 Checking ${schedule.direction} route: ${schedule.routeName}`);
      console.log(`      Schedule: ${schedule.startTime} - ${schedule.endTime}, Days: ${schedule.daysOfWeek}`);
      console.log(`      Current: ${currentTime}, Day: ${currentDay}`);
      
      // Check if current day is in schedule
      if (schedule.daysOfWeek && schedule.daysOfWeek.includes(currentDay)) {
        console.log(`      ✓ Day matches`);
        // Check if current time is within schedule window
        if (currentTime >= schedule.startTime && currentTime <= schedule.endTime) {
          console.log(`   ✅ ${schedule.direction} route active (${schedule.startTime} - ${schedule.endTime})`);
          return {
            routeId: doc.id,
            routeName: schedule.routeName || `${schedule.direction} Route`,
            direction: schedule.direction || "unknown",
            stoppings: schedule.stops || schedule.stoppings || [],
          };
        } else {
          console.log(`      ✗ Time outside window (${currentTime} not in ${schedule.startTime}-${schedule.endTime})`);
        }
      } else {
        console.log(`      ✗ Day doesn't match (${currentDay} not in ${schedule.daysOfWeek})`);
      }
    }
    
    console.log(`   ⚠️ No route active at current time`);
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
    // ✅ Use Ola Maps Directions API (POST with query params, lat,lng order)
    const origin = `${gpsData.latitude},${gpsData.longitude}`;
    const destination = `${busData.remainingStops[busData.remainingStops.length - 1].latitude},${busData.remainingStops[busData.remainingStops.length - 1].longitude}`;

    const waypoints = busData.remainingStops.length > 1
      ? busData.remainingStops
          .slice(0, -1)
          .map((stop) => `${stop.latitude},${stop.longitude}`)
          .join("|")
      : null;

    console.log(`📡 Calling Ola Maps Directions API for ${busData.remainingStops.length} stops (sequential route)...`);
    console.log(`   Origin: ${origin}`);
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

      // Calculate CUMULATIVE ETAs (each stop includes time to reach all previous stops)
      let cumulativeDuration = 0;
      const updatedStops = busData.remainingStops.map((stop, index) => {
        const leg = legs[index];

        if (leg) {
          const legDurationSeconds = leg.duration || 0;
          const legDistanceMeters = leg.distance || 0;
          
          // Add this leg's duration to cumulative total
          cumulativeDuration += legDurationSeconds;
          
          const etaMinutes = Math.round(cumulativeDuration / 60);
          const etaTimestamp = new Date(Date.now() + cumulativeDuration * 1000).toISOString();

          console.log(`   📍 ${stop.name}: ${etaMinutes} min (cumulative: ${(cumulativeDuration / 60).toFixed(1)} min, leg: ${(legDurationSeconds / 60).toFixed(1)} min, ${(legDistanceMeters / 1000).toFixed(1)} km)`);

          return {
            ...stop,
            estimatedMinutesOfArrival: etaMinutes,
            distanceMeters: legDistanceMeters,
            eta: etaTimestamp,
          };
        }

        return stop;
      });

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
    
    // FALLBACK: Calculate ETAs using distance and average speed (CUMULATIVE)
    console.log(`⚠️ Using fallback ETA calculation (distance-based, cumulative)`);
    const AVERAGE_SPEED_MPS = 8.33; // 30 km/h = 8.33 m/s (realistic city speed)
    
    // Start from current bus location
    let previousLocation = { lat: gpsData.latitude, lng: gpsData.longitude };
    let cumulativeDuration = 0;
    
    const updatedStops = busData.remainingStops.map((stop, index) => {
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