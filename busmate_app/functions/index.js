const { onSchedule } = require("firebase-functions/v2/scheduler");
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
    const startTime = Date.now();
    console.log(`🚀 Starting notification batch job at ${new Date()}`);

    try {
      // Optimized query with compound index
      const studentsSnapshot = await db
        .collection("students")
        .where("notified", "==", false)
        .where("fcmToken", "!=", null)
        .limit(100) // Process in batches to avoid timeout
        .get();

      if (studentsSnapshot.empty) {
        console.log("📭 No students to process for notifications");
        return;
      }

      console.log(`📋 Processing ${studentsSnapshot.size} students for notifications`);

      // Group students by bus ID to minimize bus_status queries
      const studentsByBus = new Map();
      studentsSnapshot.docs.forEach(doc => {
        const student = doc.data();
        const studentId = doc.id;
        
        if (!student.assignedBusId || 
            !student.stopLocation || 
            !student.notificationPreferenceByTime) {
          return;
        }

        if (!studentsByBus.has(student.assignedBusId)) {
          studentsByBus.set(student.assignedBusId, []);
        }
        studentsByBus.get(student.assignedBusId).push({ studentId, ...student });
      });

      // Process each bus batch
      const notifications = [];
      const updates = [];
      
      for (const [busId, students] of studentsByBus) {
        try {
          // Single query per bus instead of per student
          const busStatus = await db.collection("bus_status").doc(busId).get();
          const busStatusData = busStatus.data();

          if (!busStatusData || !busStatusData.isActive) {
            console.log(`⚠️ Bus ${busId} is not active, skipping students`);
            continue;
          }

          // Process all students for this bus
          for (const student of students) {
            const eta = getETAInMinutes(busStatusData, student.stopping);
            
            if (eta !== null && eta <= student.notificationPreferenceByTime) {
              console.log(`🚍 Queuing notification for ${student.name} (ETA: ${eta}min)`);

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
              
              // Queue database update
              updates.push({
                collection: 'students',
                doc: student.studentId,
                data: { notified: true }
              });
              
              // Queue timer creation
              updates.push({
                collection: 'notificationTimers',
                doc: student.studentId,
                data: {
                  notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                  parentPhone: student.parentContact,
                  smsSent: false,
                  busId: busId,
                  eta: eta
                }
              });
            }
          }
        } catch (busError) {
          console.error(`❌ Error processing bus ${busId}:`, busError);
        }
      }

      // Batch send notifications
      if (notifications.length > 0) {
        console.log(`📤 Sending ${notifications.length} notifications in batch`);
        
        try {
          // Send notifications in parallel batches of 10
          const batchSize = 10;
          for (let i = 0; i < notifications.length; i += batchSize) {
            const batch = notifications.slice(i, i + batchSize);
            await Promise.all(batch.map(async (payload) => {
              try {
                await admin.messaging().send(payload);
              } catch (msgError) {
                console.error(`❌ Failed to send notification:`, msgError);
              }
            }));
          }
          
          console.log(`✅ Successfully sent ${notifications.length} notifications`);
        } catch (error) {
          console.error(`❌ Error sending notifications:`, error);
        }
      }

      // Batch update database
      if (updates.length > 0) {
        console.log(`💾 Performing ${updates.length} database updates in batch`);
        
        const batch = db.batch();
        updates.forEach(update => {
          const ref = db.collection(update.collection).doc(update.doc);
          if (update.collection === 'notificationTimers') {
            batch.set(ref, update.data);
          } else {
            batch.update(ref, update.data);
          }
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

exports.checkNotificationTimers = onSchedule("every 1 minutes", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const timersSnapshot = await db.collection("notificationTimers")
    .where("smsSent", "==", false)
    .get();

  for (const timerDoc of timersSnapshot.docs) {
    const data = timerDoc.data();
    const notifiedAt = data.notifiedAt.toDate();
    const parentPhone = data.parentPhone;

    if (!parentPhone) continue;

    const minutesPassed = (now.toDate() - notifiedAt) / (60 * 1000);

    if (minutesPassed >= 1) {
      console.log(`📩 Sending SMS to ${parentPhone}`);

      await sendSms(parentPhone, "Your bus is about to arrive! (Auto reminder)");

      await db.collection("notificationTimers").doc(timerDoc.id).update({
        smsSent: true,
      });
    }
  }
});

function getETAInMinutes(data, studentLocationName) {
  const stop = data.remainingStops.find(
    (s) => s.name === studentLocationName
  );

  if (!stop) {
    console.log("❌ No matching stop found.");
    return null;
  }
  console.log(stop);
  return stop.estimatedMinutesOfArrival;
}


function getSoundName(language) {
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
      return "notification_english";
  }
}

async function sendSms(phoneNumber, message) {
  const apiUrl = 'http://sms.hspsms.com/sendSMS';

  const params = new URLSearchParams({
    username: 'hspdemo',
    message: `welcome to our honda family`,
    sendername: 'HSPSMS',
    smstype: 'TRANS',
    numbers: phoneNumber,
    apikey: '420c2d16-0eae-467c-804b-b10ae49d32a5'
  });

  try {
    const response = await fetch(`${apiUrl}?${params.toString()}`, {
      method: 'GET'
    });

    if (response.ok) {
      const result = await response.text(); // or .json() if it returns JSON
      console.log("✅ OTP sent successfully:", result);
    } else {
      console.log("❌ OTP sending failed:", response.status);
    }
  } catch (error) {
    console.error("❌ OTP sending error:", error);
  }
}


// notify status reset every day
exports.resetStudentNotifiedStatus = onSchedule("every day 00:00", async (event) => {
  const db = admin.firestore();

  try {
    const studentsSnapshot = await db.collection("students").get();

    const batch = db.batch();

    studentsSnapshot.forEach((studentDoc) => {
      batch.update(studentDoc.ref, { notified: false });
    });

    await batch.commit();

    console.log(`✅ Reset 'notified' field for ${studentsSnapshot.size} students`);
  } catch (error) {
    console.error("❌ Error resetting student notified status:", error);
  }
});

exports.acknowledgeNotification = functions.https.onRequest(async (req, res) => {
  const studentId = req.body.studentId;
  if (!studentId) {
    res.status(400).send("Missing studentId");
    return;
  }

  try {
    await admin.firestore()
      .collection("notificationTimers")
      .doc(studentId)
      .update({
        smsSent: true,
      });
    console.log(`✅ Acknowledged notification for studentId: ${studentId}`);
    res.status(200).send("Acknowledged");
  } catch (error) {
    console.error(error);
    res.status(500).send("Error updating Firestore");
  }
});



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
