# Quick Firebase Setup Checklist

## ✅ Things to Check in Firebase Console

### 1. Enable Email/Password Authentication
```
Firebase Console → Authentication → Sign-in method → Email/Password
Status: MUST BE ENABLED ✓
```

**How to Enable:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `busmate-b80e8`
3. Click **Authentication** in left sidebar
4. Click **Sign-in method** tab
5. Click on **Email/Password**
6. Toggle **Enable** switch to ON
7. Click **Save**

---

### 2. Update Firestore Security Rules
```
Firebase Console → Firestore Database → Rules
Status: MUST ALLOW AUTHENTICATED USERS ✓
```

**Paste these rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Then click PUBLISH button!**

---

### 3. Create Test User (Choose ONE method)

#### Method A: Using App (Easiest)
1. Run app: `flutter run`
2. Click orange **"Create Test User"** button
3. Wait for success message

#### Method B: Using Firebase Console
1. Go to **Authentication** → **Users** tab
2. Click **Add User**
3. Email: `kanish@gmail.com`
4. Password: `123456`
5. Copy the **User UID** (you'll need this!)
6. Go to **Firestore Database** → **Data** tab
7. Create collection: `students`
8. Document ID: [paste the User UID you copied]
9. Add fields:
   ```
   email: kanish@gmail.com
   name: Kanish Test User
   studentId: STU001
   schoolId: school_001
   assignedBusId: bus_001
   assignedDriverId: driver_001
   isActive: true
   createdAt: [current timestamp]
   ```
10. Click **Save**

---

## 🎯 After Setup - Test Login

1. Open app
2. Enter email: `kanish@gmail.com`
3. Enter password: `123456`
4. Click **Sign In**
5. Should see: "DEBUG: Firebase Auth successful" in console
6. Should navigate to **Stop Location** screen

---

## 🐛 Common Issues & Fixes

### Issue 1: "Failed to fetch students/drivers"
**Cause:** Firestore rules not published or too restrictive
**Fix:** Update rules in Firebase Console and click PUBLISH

### Issue 2: "Invalid email or password"
**Cause:** User doesn't exist in Firebase Authentication
**Fix:** Create user using one of the methods above

### Issue 3: "User authenticated but no student/driver record found"
**Cause:** User exists in Auth but not in Firestore database
**Fix:** Create Firestore document with same UID as Auth user

### Issue 4: "Permission denied"
**Cause:** Firestore rules blocking access
**Fix:** Use the development rules above (allow all authenticated)

---

## 📱 Expected Console Output (Success)

When login works correctly, you should see:
```
DEBUG: Starting login attempt for userId: kanish@gmail.com
DEBUG: Firebase Auth successful for UID: [some-uid-here]
DEBUG: User is a student
DEBUG: FCM token updated successfully
DEBUG: Navigating to stop location
```

---

## 🔒 Security Note

The rules above are for **DEVELOPMENT ONLY**. Before going to production:
1. Implement proper user roles (admin, student, driver)
2. Use field-level security rules
3. Validate data on write
4. Limit read access based on relationships
5. Add rate limiting
6. Enable App Check

See `FIRESTORE_RULES_SETUP.md` for production-ready rules.
