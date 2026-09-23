#!/usr/bin/env node
/**
 * Add 2 test admin users to dev Firebase Firestore
 * This uses the Firebase REST API to directly add documents
 */

const https = require('https');

const DEV_PROJECT_ID = 'busmate-dev';
const FIRESTORE_API_URL = `https://firestore.googleapis.com/v1/projects/${DEV_PROJECT_ID}/databases/(default)/documents/adminusers`;

// Two test admin accounts
const testAdmins = [
  {
    name: 'Test Admin 1',
    email: 'testadmin1@busmate-dev.com',
    role: 'superior',
    schoolId: 'test-school-001'
  },
  {
    name: 'Test Admin 2', 
    email: 'testadmin2@busmate-dev.com',
    role: 'admin',
    schoolId: 'test-school-001'
  }
];

function formatFirestoreValue(value) {
  if (typeof value === 'string') {
    return { stringValue: value };
  } else if (typeof value === 'number') {
    return { integerValue: value.toString() };
  } else if (typeof value === 'boolean') {
    return { booleanValue: value };
  }
  return { stringValue: value.toString() };
}

function createDocumentPayload(admin, docId) {
  return {
    fields: {
      name: formatFirestoreValue(admin.name),
      email: formatFirestoreValue(admin.email),
      role: formatFirestoreValue(admin.role),
      schoolId: formatFirestoreValue(admin.schoolId),
      createdAt: { timestampValue: new Date().toISOString() },
      uid: formatFirestoreValue(docId)
    }
  };
}

async function addAdmins() {
  console.log('📝 Adding 2 test admins to dev Firebase...\n');
  
  for (let i = 0; i < testAdmins.length; i++) {
    const admin = testAdmins[i];
    const docId = `test-admin-${i + 1}-${Date.now()}`;
    const payload = createDocumentPayload(admin, docId);
    
    try {
      const url = new URL(`${FIRESTORE_API_URL}/${docId}`);
      
      const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json'
        }
      };

      // Make request without auth for open Firestore (dev mode usually allows)
      await new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              console.log(`✅ Added admin: ${admin.email}`);
              console.log(`   - ID: ${docId}`);
              console.log(`   - Role: ${admin.role}`);
              console.log(`   - School: ${admin.schoolId}\n`);
              resolve();
            } else {
              reject(new Error(`HTTP ${res.statusCode}: ${data}`));
            }
          });
        });
        
        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
      });
    } catch (error) {
      console.error(`❌ Failed to add ${admin.email}:`, error.message);
    }
  }
  
  console.log('✨ Done! Test admins added to dev Firebase.');
  console.log('\n📌 Note: You can now use these accounts in the dev app:');
  testAdmins.forEach(admin => {
    console.log(`   - ${admin.email} (${admin.role})`);
  });
}

addAdmins().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
