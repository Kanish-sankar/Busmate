# Fix Permission Denied Errors - Set Claims for Existing Users

## Problem
Users who logged in BEFORE the security rules were deployed don't have custom claims set. This causes permission denied errors.

## Solution Options

### Option 1: Log Out and Back In (RECOMMENDED - Easiest)
1. Open the mobile app
2. Log out completely
3. Log back in with your email and password
4. The app will automatically set your claims and refresh your token
5. Everything will work!

### Option 2: Run Cloud Function Manually (For Multiple Users)

If you have many users and want to set claims for all of them at once, run this in Firebase Console:

1. Go to Firebase Console → Functions
2. Click on `setUserClaims` function
3. Or run this script in your terminal:

```bash
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"
node set-all-user-claims.js
```

### Option 3: Create a One-Time Trigger (For All Existing Users)

Create a temporary Cloud Function to set claims for ALL existing users:

```javascript
// Add this to functions/index.js temporarily
exports.fixAllUserClaims = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    const db = admin.firestore();
    
    try {
      const usersSnapshot = await db.collection("adminusers").get();
      const results = [];
      
      for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        const uid = doc.id;
        const role = userData.role;
        const schoolId = userData.schoolId;
        const assignedBusId = userData.assignedBusId;
        const assignedRouteId = userData.assignedRouteId;
        
        if (!role || !schoolId) {
          results.push({ uid, status: 'skipped', reason: 'missing role or schoolId' });
          continue;
        }
        
        const claims = { role, schoolId };
        if (assignedBusId) claims.assignedBusId = assignedBusId;
        if (assignedRouteId) claims.assignedRouteId = assignedRouteId;
        
        try {
          await admin.auth().setCustomUserClaims(uid, claims);
          results.push({ uid, status: 'success', claims });
        } catch (error) {
          results.push({ uid, status: 'error', error: error.message });
        }
      }
      
      res.json({ 
        message: 'Claims update complete', 
        total: usersSnapshot.docs.length,
        results 
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);
```

Then deploy and call it:
```bash
firebase deploy --only functions:fixAllUserClaims
curl https://us-central1-busmate-b80e8.cloudfunctions.net/fixAllUserClaims
```

**IMPORTANT: Delete this function after running it once!**

## What Changed

### Security Rules Now Require Custom Claims
- **Firestore**: Checks `request.auth.token.role` and `request.auth.token.schoolId`
- **Realtime Database**: Checks `auth.token.role` and `auth.token.schoolId`
- Without these claims, all database access is denied

### App Now Auto-Sets Claims
- `auth_login.dart`: Calls `setUserClaims` if claims are missing
- `dashboard.controller.dart`: Checks claims on startup
- `driver.controller.dart`: Checks claims on startup

## Verify Claims Are Set

To check if a user has claims set, use Firebase Console:
1. Go to Authentication → Users
2. Click on a user
3. Scroll to "Custom Claims"
4. Should see: `{"role":"student","schoolId":"SCH123","assignedBusId":"BUS456"}`

Or use this Node.js script:
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

async function checkClaims(email) {
  const user = await admin.auth().getUserByEmail(email);
  const idTokenResult = await admin.auth().getUser(user.uid);
  console.log('Custom Claims:', user.customClaims);
}

checkClaims('student@example.com');
```
