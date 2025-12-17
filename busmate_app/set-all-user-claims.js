// Quick script to set custom claims for all existing users
// Run once to fix permission denied errors after security rules deployment

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json'); // You need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://busmate-b80e8-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function setClaimsForAllUsers() {
  console.log('🔧 Starting to set custom claims for all users...\n');
  
  try {
    const usersSnapshot = await db.collection('adminusers').get();
    const total = usersSnapshot.docs.length;
    let success = 0;
    let skipped = 0;
    let failed = 0;
    
    console.log(`Found ${total} users in adminusers collection\n`);
    
    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const uid = doc.id;
      const email = userData.email || 'unknown';
      const role = userData.role;
      const schoolId = userData.schoolId;
      const assignedBusId = userData.assignedBusId;
      const assignedRouteId = userData.assignedRouteId;
      
      if (!role || !schoolId) {
        console.log(`⏭️  Skipped ${email}: missing role or schoolId`);
        skipped++;
        continue;
      }
      
      const claims = { role, schoolId };
      if (assignedBusId) claims.assignedBusId = assignedBusId;
      if (assignedRouteId) claims.assignedRouteId = assignedRouteId;
      
      try {
        await admin.auth().setCustomUserClaims(uid, claims);
        console.log(`✅ Set claims for ${email}: role=${role}, schoolId=${schoolId}`);
        success++;
      } catch (error) {
        console.log(`❌ Failed for ${email}: ${error.message}`);
        failed++;
      }
    }
    
    console.log('\n📊 Summary:');
    console.log(`Total users: ${total}`);
    console.log(`✅ Success: ${success}`);
    console.log(`⏭️  Skipped: ${skipped}`);
    console.log(`❌ Failed: ${failed}`);
    console.log('\n✨ Done! Users need to log out and back in to get fresh tokens.');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

setClaimsForAllUsers();
