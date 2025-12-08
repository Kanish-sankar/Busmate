#!/usr/bin/env node

/**
 * Migrate Regional Admins from adminusers to admins collection
 * Run this script locally: node migrate-regional-admins.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, 'firebase-adminsdk.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin initialized with service account');
} catch (error) {
  console.error('❌ Error loading service account. Make sure firebase-adminsdk.json exists in project root');
  console.error('   Download it from Firebase Console → Project Settings → Service Accounts → Generate New Private Key');
  process.exit(1);
}

const db = admin.firestore();

async function migrateRegionalAdmins() {
  try {
    console.log('\n🔍 Searching for regional admins in adminusers collection...\n');

    // Get all regional admins from adminusers
    const adminUsersSnapshot = await db
      .collection('adminusers')
      .where('role', '==', 'regionalAdmin')
      .get();

    if (adminUsersSnapshot.empty) {
      console.log('✅ No regional admins found in adminusers collection');
      return;
    }

    console.log(`Found ${adminUsersSnapshot.size} regional admin(s) to migrate:\n`);

    let migratedCount = 0;
    const errors = [];

    for (const doc of adminUsersSnapshot.docs) {
      const userId = doc.id;
      const data = doc.data();

      try {
        console.log(`Migrating: ${userId}`);
        console.log(`  Email: ${data.email}`);
        console.log(`  School: ${data.schoolId}`);

        // Check if already exists in admins collection
        const existingDoc = await db.collection('admins').doc(userId).get();
        
        if (existingDoc.exists) {
          console.log(`  ⚠️  Already exists in admins collection, skipping...`);
          continue;
        }

        // Copy to admins collection
        await db.collection('admins').doc(userId).set({
          email: data.email,
          role: 'regionalAdmin',
          schoolId: data.schoolId,
          permissions: data.permissions || {},
          adminName: data.adminName || '',
          adminID: data.adminID || userId,
          createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          migratedFrom: 'adminusers',
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`  ✅ Successfully migrated to admins collection\n`);
        migratedCount++;
      } catch (error) {
        const errorMsg = `Failed to migrate ${userId}: ${error.message}`;
        console.log(`  ❌ ${errorMsg}\n`);
        errors.push(errorMsg);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log(`✅ Migration complete: ${migratedCount}/${adminUsersSnapshot.size} admins migrated`);
    console.log('='.repeat(60));

    if (errors.length > 0) {
      console.log('\n⚠️  Errors occurred:');
      errors.forEach(err => console.log(`  - ${err}`));
    }

    console.log('\n📝 Next steps:');
    console.log('  1. Test login with migrated regional admin accounts');
    console.log('  2. Verify they appear in the admins collection in Firebase Console');
    console.log('  3. Once verified, you can delete entries from adminusers collection');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migration
migrateRegionalAdmins();
