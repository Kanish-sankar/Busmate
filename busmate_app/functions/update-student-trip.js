const admin = require('firebase-admin');

// Use application default credentials (from Firebase CLI)
process.env.GOOGLE_APPLICATION_CREDENTIALS = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
process.env.GCLOUD_PROJECT = 'busmate-b80e8';
process.env.FIRESTORE_EMULATOR_HOST = '';

admin.initializeApp({
  projectId: 'busmate-b80e8'
});

const db = admin.firestore();
const schoolId = 'SCH1761403353624';
const busId = '1QX7a0pKcZozDV5Riq6i';
const correctTripId = 'ER3aQzpZhdRLFqNE6nvM_2025-12-09_13:17';

async function updateStudents() {
  console.log(`🔄 Updating students for bus ${busId} to trip ${correctTripId}`);
  
  try {
    const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
    const studentsSnapshot = await studentsRef
      .where('assignedBusId', '==', busId)
      .get();
    
    if (studentsSnapshot.empty) {
      console.log('⚠️ No students found for this bus');
      process.exit(0);
    }
    
    console.log(`\nFound ${studentsSnapshot.size} students assigned to bus ${busId}:\n`);
    
    const batch = db.batch();
    let count = 0;
    
    studentsSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`   Student: ${data.name || doc.id}`);
      console.log(`      Current tripId: ${data.currentTripId || 'null'}`);
      console.log(`      Notified: ${data.notified}`);
      console.log(`      Stop: ${data.stopping || 'N/A'}`);
      console.log(`      Preference: ${data.notificationPreferenceByTime || 'N/A'} min`);
      console.log(`      FCM Token: ${data.fcmToken ? 'Present' : 'Missing'}`);
      console.log('');
      
      batch.update(doc.ref, {
        currentTripId: correctTripId,
        notified: false,
        lastNotifiedRoute: 'ER3aQzpZhdRLFqNE6nvM',
        lastNotifiedAt: null,
        tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });
    
    await batch.commit();
    console.log(`✅ Successfully updated ${count} students to trip ${correctTripId}`);
    console.log('✅ All students reset to notified=false and ready for notifications!');
    
  } catch (error) {
    console.error('❌ Error updating students:', error);
  }
  
  process.exit(0);
}

updateStudents();
