# Fix Permission Denied Errors on Web Portal

## Problem
The web portal shows "permission-denied" errors because the superior admin user doesn't have custom claims set in their authentication token.

## Solution

### Option 1: Browser Console (FASTEST - 30 seconds)

1. **Open the web app** (http://localhost in Chrome)
2. **Press F12** to open Developer Tools
3. **Go to Console tab**
4. **Paste this code** and press Enter:

```javascript
// Set custom claims for current user
const user = firebase.auth().currentUser;
const setUserClaims = firebase.functions().httpsCallable('setUserClaims');
await setUserClaims({ uid: user.uid });
await user.getIdToken(true);
const tokenResult = await user.getIdTokenResult();
console.log('✅ Claims set:', tokenResult.claims);
location.reload();
```

5. **Wait for page to reload** - Dashboard should now load!

---

### Option 2: Logout and Login (RECOMMENDED)

1. **Logout** from the web portal
2. **Login again** with your credentials
3. The updated `auth_controller.dart` will automatically set custom claims during login
4. Dashboard should load properly

---

### Option 3: Use the Script File

1. **Open** `SET_CLAIMS_CONSOLE.js` in this folder
2. **Copy all the code**
3. **Open browser console** (F12 → Console tab)
4. **Paste and press Enter**
5. **Wait for "SUCCESS!" message**
6. **Reload the page**: `location.reload()`

---

## Verification

After applying any solution, verify claims are set:

```javascript
firebase.auth().currentUser.getIdTokenResult().then(token => {
  console.log("Custom Claims:", token.claims);
  // Should show: {role: "superior", schoolId: "", ...}
});
```

## What Was Fixed

### Updated Files:
1. **firestore.rules** - Simplified permissions for superior/school admins
2. **database.rules.json** - Added proper RTDB permissions
3. **auth_controller.dart** - Added automatic custom claims check on login

### New Permissions:
- ✅ **Superior Admins**: Full read/write access to ALL collections
- ✅ **School Admins**: Full read/write access to THEIR school only
- ✅ **Drivers**: Read their school, write GPS for their bus
- ✅ **Students**: Read their school, update own preferences

## If Still Not Working

1. **Check Firebase Console** → Authentication → Users → Your Email → Custom Claims
2. **Should see**: `{"role": "superior", "schoolId": ""}`
3. **If empty**, run the browser console commands above
4. **Check Cloud Functions logs** in Firebase Console for errors

## Need Help?

- Check [SECURITY_RULES_REFERENCE.md](../busmate_app/SECURITY_RULES_REFERENCE.md) for complete documentation
- Verify the user is in `/admins` collection in Firestore
- Make sure user has role='superior' in Firestore document
