// Quick test to manually check notification logic
const admin = require("firebase-admin");

// Initialize - will use default credentials from Firebase CLI
admin.initializeApp({
  databaseURL: "https://busmate-b80e8-default-rtdb.asia-southeast1.firebasedatabase.app"
});

async function testNotifications() {
  const db = admin.firestore();
  const rtdb = admin.database();
  
  console.log("🔍 Testing notification logic...\n");
  
  try {
    // 1. Query students
    console.log("1️⃣ Querying students from collectionGroup...");
    const studentsSnapshot = await db
      .collectionGroup("students")
      .where("notified", "==", false)
      .where("fcmToken", "!=", null)
      .limit(10)
      .get();
    
    console.log(`   Found ${studentsSnapshot.size} students`);
    
    studentsSnapshot.docs.forEach(doc => {
      const student = doc.data();
      const path = doc.ref.path;
      console.log(`   📋 ${student.name} (${doc.id})`);
      console.log(`      Path: ${path}`);
      console.log(`      Bus: ${student.assignedBusId}`);
      console.log(`      School: ${student.schoolId}`);
      console.log(`      Stop: ${student.stopping}`);
      console.log(`      Preference: ${student.notificationPreferenceByTime} min`);
      console.log(`      FCM Token: ${student.fcmToken?.substring(0, 20)}...`);
    });
    
    // 2. Check bus location data
    if (studentsSnapshot.size > 0) {
      const firstStudent = studentsSnapshot.docs[0].data();
      const busId = firstStudent.assignedBusId;
      const schoolId = firstStudent.schoolId;
      
      console.log(`\n2️⃣ Checking bus location data...`);
      console.log(`   Path: bus_locations/${schoolId}/${busId}`);
      
      const busSnapshot = await rtdb.ref(`bus_locations/${schoolId}/${busId}`).once('value');
      const busData = busSnapshot.val();
      
      if (busData) {
        console.log(`   ✅ Bus data found:`);
        console.log(`      isActive: ${busData.isActive}`);
        console.log(`      activeRouteId: ${busData.activeRouteId}`);
        console.log(`      remainingStops: ${busData.remainingStops?.length || 0}`);
        
        if (busData.remainingStops && busData.remainingStops.length > 0) {
          console.log(`\n   📍 Remaining stops:`);
          busData.remainingStops.forEach((stop, idx) => {
            console.log(`      ${idx + 1}. ${stop.name}`);
            console.log(`         ETA: ${stop.estimatedMinutesOfArrival?.toFixed(1) || 'N/A'} min`);
            console.log(`         Coords: (${stop.latitude}, ${stop.longitude})`);
          });
          
          // 3. Check if student's stop matches
          console.log(`\n3️⃣ Matching student stop "${firstStudent.stopping}"...`);
          const matchingStop = busData.remainingStops.find(s => s.name === firstStudent.stopping);
          
          if (matchingStop) {
            console.log(`   ✅ MATCH FOUND!`);
            console.log(`      ETA: ${matchingStop.estimatedMinutesOfArrival?.toFixed(1)} minutes`);
            console.log(`      Threshold: ${firstStudent.notificationPreferenceByTime} minutes`);
            
            if (matchingStop.estimatedMinutesOfArrival <= firstStudent.notificationPreferenceByTime) {
              console.log(`      🎯 SHOULD NOTIFY! (${matchingStop.estimatedMinutesOfArrival} <= ${firstStudent.notificationPreferenceByTime})`);
            } else {
              console.log(`      ⏸️ Not yet - bus too far (${matchingStop.estimatedMinutesOfArrival} > ${firstStudent.notificationPreferenceByTime})`);
            }
          } else {
            console.log(`   ❌ No match found in remaining stops`);
          }
        } else {
          console.log(`   ⚠️ No remaining stops - bus may not be on active route`);
        }
      } else {
        console.log(`   ❌ No bus data found`);
      }
    }
    
  } catch (error) {
    console.error("❌ Error:", error);
  }
  
  process.exit(0);
}

testNotifications();
