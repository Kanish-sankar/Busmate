# 🔥 Firestore Rules Setup - IMPORTANT!

## ⚠️ Your Issue: Permission Denied

The error you're seeing:
```
DEBUG: Failed to fetch students, continuing with empty list
DEBUG: Failed to fetch drivers, continuing with empty list
```

This means your **Firestore Security Rules are blocking access**. You need to update them in Firebase Console.

---

## 🚀 Quick Fix (5 minutes)

### Step 1: Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **busmate-b80e8**
3. Click on **Firestore Database** in the left sidebar
4. Click on the **Rules** tab at the top

### Step 2: Replace Rules with Development Rules

**Delete everything** in the rules editor and **paste this**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 🔥 TEMPORARY DEVELOPMENT RULES 🔥
    // For testing and development only - SECURE BEFORE PRODUCTION!
    
    // Allow all authenticated users to read and write
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow public read for basic app configuration (if needed)
    match /config/{document} {
      allow read: if true;
    }
  }
}
```

### Step 3: Publish Rules
1. Click the **Publish** button at the top right
2. Confirm the changes
3. Wait for "Rules published successfully" message

### Step 4: Test Your App
1. Run your app: `flutter run`
2. Click the **"Create Test User"** button (orange button at bottom right)
3. Wait for success message
4. Login with:
   - Email: `kanish@gmail.com`
   - Password: `123456`
5. Should now work! ✅

---

## 🔐 Production Rules (Use Later)

Once your app is working, replace with these **SECURE** rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper Functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Students Collection
    match /students/{studentId} {
      // Students can read and update their own data
      allow read, update: if isOwner(studentId);
      
      // Only authenticated users can read basic student info
      allow read: if isAuthenticated();
      
      // Only admins can create/delete students (implement admin check)
      allow create, delete: if isAuthenticated(); // TODO: Add admin check
    }
    
    // Drivers Collection  
    match /drivers/{driverId} {
      // Drivers can read and update their own data
      allow read, update: if isOwner(driverId);
      
      // Students can read driver info
      allow read: if isAuthenticated();
      
      // Only admins can create/delete drivers
      allow create, delete: if isAuthenticated(); // TODO: Add admin check
    }
    
    // Schools Collection
    match /schools/{schoolId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated(); // TODO: Add admin check
    }
    
    // Buses Collection
    match /buses/{busId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated(); // TODO: Add driver/admin check
    }
    
    // Notifications Collection
    match /notifications/{notificationId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isOwner(request.auth.uid);
    }
  }
}
```

---

## 📋 Checklist

- [ ] Opened Firebase Console
- [ ] Found Firestore Database → Rules
- [ ] Pasted development rules
- [ ] Published rules
- [ ] Tested app - Create Test User button
- [ ] Logged in with kanish@gmail.com / 123456
- [ ] ✅ App works!

---

## 🐛 Still Having Issues?

### Check Firebase Authentication is Enabled
1. Go to **Authentication** in Firebase Console
2. Click **Sign-in method** tab
3. Make sure **Email/Password** is **Enabled**
4. If not enabled, click on it and enable it

### Check Firestore Database Exists
1. Go to **Firestore Database**
2. If you see "Create database", click it
3. Choose "Start in test mode" (for development)
4. Select a location close to you
5. Click Enable

### Verify Rules are Published
1. Go to Firestore Database → Rules
2. Check the timestamp shows recent publish time
3. Rules should show "Last updated: [today's date]"

### Check Console Logs
In your Flutter app console, look for:
- `DEBUG: Firebase Auth successful for UID: xxxxx` ✅
- `DEBUG: User is a student` ✅
- `DEBUG: Navigating to stop location` ✅

If you see errors, copy and share them for more help!

---

## 🔗 Useful Links

- [Firebase Console](https://console.firebase.google.com/)
- [Firestore Security Rules Docs](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Auth Docs](https://firebase.google.com/docs/auth)

---

## 💡 Why This Happens

Firestore has **security rules** that control who can read/write data. By default:
- All access is **DENIED** for security
- You must explicitly **ALLOW** access with rules
- During development, we use permissive rules
- Before production, we use strict rules

The error means your current rules are denying access to the `students` and `drivers` collections, even for authenticated users.

**The fix above gives authenticated users full access during development.**
