const { onSchedule } = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const nodemailer = require('nodemailer');


admin.initializeApp();

exports.sendBusArrivalNotifications = onSchedule("every 1 minutes", async (event) => {
  const db = admin.firestore();

  try {
    const studentsSnapshot = await db.collection("students").get();

    for (const studentDoc of studentsSnapshot.docs) {
      const student = studentDoc.data();
      const studentId = studentDoc.id;

      if (!student.stopLocation || !student.notificationPreferenceByTime || !student.fcmToken || student.notified) {
        continue;
      }

      // Fetch Bus Current Data
      const busStatus = await db.collection("bus_status").doc(student.assignedBusId).get();
      const busStatusData = busStatus.data();

      if (!busStatusData) continue;

      const eta = getETAInMinutes(busStatusData, student.stopping);
      if (eta !== null) {
        console.log(`Student: ${student.name}, Stop: ${student.stopping}, ETA: ${eta} min`);
      }

      if (eta <= student.notificationPreferenceByTime) {
        console.log(`🚍 Sending notification to ${student.name}`);

        const isVoiceNotification = (student.notificationType || "").toLowerCase() === "voice notification";

        const payload = {
          notification: {
            title: "Bus Approaching!",
            body: `Bus will arrive in approximately ${eta.toFixed(0)} minutes.`,
          },
          android: {
            priority: "high",
            ttl: 1 * 60 * 1000,
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
              "apns-expiration": "60000",
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
            studentId: studentId,
            notificationType: isVoiceNotification ? "Voice Notification" : "Text Notification",
            selectedLanguage: student.languagePreference || "english",
          },
          token: student.fcmToken,
        };

        await admin.messaging().send(payload);

        // Mark as notified
        await db.collection("students").doc(studentId).update({
          notified: true,
        });

        // Start 1 minute timer (simulate using Firestore document)
        await db.collection("notificationTimers").doc(studentId).set({
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          parentPhone: student.parentContact,
          smsSent: false,
        });
      }
    }
  } catch (error) {
    console.error("Error in sendBusArrivalNotifications:", error);
  }
});

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
