# Temporary Admin Credentials for BusMate Web App

## Quick Setup Instructions

### Option 1: Use These Test Credentials (if already created in Firebase Console)

**Super Admin Account:**
- Email: `superadmin@busmate.com`
- Password: `SuperAdmin123!`
- Role: `superAdmin`

**School Admin Account:**
- Email: `schooladmin@busmate.com` 
- Password: `SchoolAdmin123!`
- Role: `schoolAdmin`
- School ID: `test-school-001`

### Option 2: Create Admin Manually in Firebase Console

1. **Go to Firebase Console → Authentication**
   - Add new user with email/password
   - Note down the User UID

2. **Go to Firestore Database → Create Collection: `adminusers`**
   - Document ID: [Use the User UID from step 1]
   - Fields:
     ```
     email: "youremail@test.com"
     role: "superAdmin"  (or "schoolAdmin")
     createdAt: [Current Timestamp]
     displayName: "Test Admin"
     schoolId: "test-school-001"  (only for schoolAdmin)
     ```

3. **For School Admin, also create Schools collection:**
   - Collection: `schools`
   - Document ID: `test-school-001`
   - Fields:
     ```
     name: "Test School"
     address: "123 Test Street"
     contactEmail: "schooladmin@test.com"
     adminsEmails: ["schooladmin@test.com"]
     createdAt: [Current Timestamp]
     ```

### Option 3: Alternative Test Credentials

If the above don't work, try these:

**Test Admin 1:**
- Email: `admin@test.com`
- Password: `admin123`

**Test Admin 2:**
- Email: `testuser@gmail.com`
- Password: `test123456`

## Firebase Setup Check

Make sure your Firebase project has:
1. ✅ Authentication enabled (Email/Password)
2. ✅ Firestore Database created
3. ✅ Firebase config properly set in your app
4. ✅ Security rules allow admin user creation

## Troubleshooting Login Issues

If you're still getting "login failed":

1. **Check Firebase Console → Authentication**
   - Verify the user exists
   - Check if account is enabled

2. **Check Firebase Console → Firestore**
   - Verify `adminusers` collection exists
   - Verify document with user's UID exists
   - Check the `role` field value

3. **Check Browser Console**
   - Look for detailed error messages
   - Check network tab for Firebase API errors

4. **Check Firebase Rules**
   - Ensure adminusers collection is readable by authenticated users
   - Current rules might be too restrictive

## Quick Firebase Rules Fix

If login fails due to permission issues, temporarily use these relaxed rules in Firestore:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Temporary relaxed rules for testing
    match /adminusers/{userId} {
      allow read, write: if request.auth != null;
    }
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**⚠️ Remember to restore secure rules after testing!**

## Contact

If you need help creating these accounts or troubleshooting, let me know!









