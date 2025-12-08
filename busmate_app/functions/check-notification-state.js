// Quick diagnostic to check why notifications aren't sending
const admin = require("firebase-admin");

admin.initializeApp({
  databaseURL: "https://busmate-b80e8-default-rtdb.asia-southeast1.firebasedatabase.app"
});

async function checkState() {
  const db = admin.firestore();
  const rtdb = admin.database();
  
  console.log("🔍 Checking notification readiness...\n");
  
  try {
    // 1. Check student document
    console.log("1️⃣ Student Document (schooldetails/SCH1761403353624/students/ccy3tWQ5Mt4lJvoYKYWy):");
    const studentDoc = await db
      .collection("schooldetails")
      .doc("SCH1761403353624")
      .collection("students")
      .doc("ccy3tWQ5Mt4lJvoYKYWy")
      .get();
    
    if (studentDoc.exists) {
      const data = studentDoc.data();
      console.log(`   ✅ Found`);
      console.log(`   - notified: ${data.notified}`);
      console.log(`   - fcmToken: ${data.fcmToken ? data.fcmToken.substring(0, 30) + '...' : 'MISSING'}`);
      console.log(`   - stopping: ${data.stopping}`);
      console.log(`   - assignedBusId: ${data.assignedBusId}`);
      console.log(`   - notificationPreferenceByTime: ${data.notificationPreferenceByTime} min`);
    } else {
      console.log(`   ❌ NOT FOUND`);
    }
    
    // 2. Check bus location in RTDB
    console.log("\n2️⃣ Bus Location (bus_locations/SCH1761403353624/1QX7a0pKcZozDV5Riq6i):");
    const busSnapshot = await rtdb.ref("bus_locations/SCH1761403353624/1QX7a0pKcZozDV5Riq6i").once("value");
    const busData = busSnapshot.val();
    
    if (busData) {
      console.log(`   ✅ Found`);
      console.log(`   - isActive: ${busData.isActive}`);
      console.log(`   - activeRouteId: ${busData.activeRouteId}`);
      console.log(`   - remainingStops count: ${busData.remainingStops?.length || 0}`);
      console.log(`   - tripDirection: ${busData.tripDirection}`);
      
      if (busData.remainingStops && busData.remainingStops.length > 0) {
        console.log(`\n   📍 Remaining Stops:`);
        busData.remainingStops.slice(0, 5).forEach((stop, idx) => {
          console.log(`      ${idx + 1}. ${stop.name}`);
          console.log(`         - ETA: ${stop.estimatedMinutesOfArrival?.toFixed(1) || 'N/A'} min`);
          console.log(`         - Distance: ${stop.distanceMeters || 'N/A'} m`);
        });
        
        // 3. Check if student's stop is in remaining stops
        const studentStop = "Coimbatore-Trichy Road, Ondipudur, Sulur, Coimbatore, Tamil Nadu, 641103, India";
        console.log(`\n3️⃣ Looking for student stop: "${studentStop}"`);
        
        const matchingStop = busData.remainingStops.find(s => s.name === studentStop);
        if (matchingStop) {
          console.log(`   ✅ FOUND in remaining stops!`);
          console.log(`      - ETA: ${matchingStop.estimatedMinutesOfArrival} minutes`);
          console.log(`      - Notification threshold: 10 minutes`);
          console.log(`      - Should notify: ${matchingStop.estimatedMinutesOfArrival <= 10 ? 'YES ✅' : 'NO ⏸️'}`);
        } else {
          console.log(`   ❌ NOT FOUND in remaining stops`);
          console.log(`   Available stops: ${busData.remainingStops.map(s => s.name).join(', ')}`);
        }
      } else {
        console.log(`   ⚠️ No remaining stops - route completed or not started`);
      }
    } else {
      console.log(`   ❌ NOT FOUND`);
    }
    
  } catch (error) {
    console.error("❌ Error:", error);
  }
  
  process.exit(0);
}

checkState();
