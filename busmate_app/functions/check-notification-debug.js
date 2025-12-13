const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./busmate-b80e8-firebase-adminsdk-o3r2l-e3f59eeff0.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://busmate-b80e8-default-rtdb.firebaseio.com'
});

const db = admin.firestore();
const rtdb = admin.database();

async function checkNotificationState() {
  console.log('🔍 Checking notification state...\n');

  // 1. Check student
  console.log('1️⃣ Student Data:');
  const studentDoc = await db.collection('schooldetails/SCH1765270834407/students').doc('GvhoVtz0hsTTVU4n0bXy').get();
  const student = studentDoc.data();
  console.log(`   Name: ${student.name}`);
  console.log(`   Stop: ${student.stopping}`);
  console.log(`   Notified: ${student.notified}`);
  console.log(`   CurrentTripId: ${student.currentTripId}`);
  console.log(`   NotificationPreference: ${student.notificationPreferenceByTime} min`);
  console.log(`   FCM Token: ${student.fcmToken ? 'Present' : 'Missing'}`);

  // 2. Check bus location
  console.log('\n2️⃣ Bus Location Data:');
  const busSnapshot = await rtdb.ref('bus_locations/SCH1765270834407/PBGOivVrrFfaAADMKR6a').once('value');
  const busData = busSnapshot.val();
  console.log(`   IsActive: ${busData.isActive}`);
  console.log(`   CurrentTripId: ${busData.currentTripId}`);
  console.log(`   RemainingStops Count: ${busData.remainingStops?.length || 0}`);
  
  // 3. Check each stop
  console.log('\n3️⃣ Remaining Stops Detail:');
  if (busData.remainingStops && busData.remainingStops.length > 0) {
    busData.remainingStops.forEach((stop, index) => {
      console.log(`   Stop ${index}: "${stop.name}"`);
      console.log(`      ETA: ${stop.estimatedMinutesOfArrival} min`);
      console.log(`      Lat: ${stop.latitude}, Lng: ${stop.longitude}`);
      
      if (stop.name === student.stopping) {
        console.log(`      ✅ MATCH! This is the student's stop!`);
        if (stop.estimatedMinutesOfArrival <= student.notificationPreferenceByTime) {
          console.log(`      ✅ SHOULD NOTIFY! ETA (${stop.estimatedMinutesOfArrival}) <= Preference (${student.notificationPreferenceByTime})`);
        } else {
          console.log(`      ❌ TOO FAR: ETA (${stop.estimatedMinutesOfArrival}) > Preference (${student.notificationPreferenceByTime})`);
        }
      }
    });
  } else {
    console.log('   ❌ NO STOPS FOUND!');
  }

  // 4. Check tripId match
  console.log('\n4️⃣ TripId Match:');
  console.log(`   Student: "${student.currentTripId}"`);
  console.log(`   Bus:     "${busData.currentTripId}"`);
  console.log(`   Match: ${student.currentTripId === busData.currentTripId ? '✅ YES' : '❌ NO'}`);

  // 5. Summary
  console.log('\n5️⃣ Notification Checklist:');
  const checks = {
    'Student notified=false': !student.notified,
    'Bus isActive=true': busData.isActive,
    'TripId match': student.currentTripId === busData.currentTripId,
    'FCM token present': !!student.fcmToken,
    'Has stops': busData.remainingStops?.length > 0,
  };

  Object.entries(checks).forEach(([check, pass]) => {
    console.log(`   ${pass ? '✅' : '❌'} ${check}`);
  });

  process.exit(0);
}

checkNotificationState().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
