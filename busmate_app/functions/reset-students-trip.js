// Quick script to reset students for current trip
const admin = require('firebase-admin');

// Initialize if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const schoolId = 'SCH1761403353624';
const busId = '1QX7a0pKcZozDV5Riq6i';
const tripId = 'ER3aQzpZhdRLFqNE6nvM_2025-12-09_13:17';

async function resetStudentsForTrip() {
  console.log(`🔄 Resetting students for bus ${busId} on trip ${tripId}`);
  
  try {
    const studentsRef = db.collection(`schooldetails/${schoolId}/students`);
    const studentsSnapshot = await studentsRef
      .where('assignedBusId', '==', busId)
      .get();
    
    if (studentsSnapshot.empty) {
      console.log('⚠️ No students found for this bus');
      return;
    }
    
    console.log(`Found ${studentsSnapshot.size} students assigned to bus ${busId}`);
    
    const batch = db.batch();
    let count = 0;
    
    studentsSnapshot.forEach((doc) => {
      batch.update(doc.ref, {
        notified: false,
        lastNotifiedRoute: 'ER3aQzpZhdRLFqNE6nvM',
        lastNotifiedAt: null,
        currentTripId: tripId,
        tripStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
      console.log(`   - ${doc.data().name || doc.id}: Reset to notified=false`);
    });
    
    await batch.commit();
    console.log(`✅ Successfully reset ${count} students for trip ${tripId}`);
    console.log('✅ Students are now ready to receive notifications!');
    
  } catch (error) {
    console.error('❌ Error resetting students:', error);
  }
  
  process.exit(0);
}

resetStudentsForTrip();
