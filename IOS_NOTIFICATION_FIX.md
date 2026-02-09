# iOS GPS Bus Notification Fix - Complete Solution

## Problem
GPS-based bus arrival notifications were working on **Android** but **NOT on iOS**.
Language setting notifications worked on iOS, proving basic notification setup was correct.

---

## Root Causes Identified & Fixed

### ✅ Issue 1: Missing UNUserNotificationCenterDelegate Implementation (AppDelegate.swift)

**Before (Broken):**
```swift
UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```
The `as?` optional cast was silently failing because the class didn't actually conform to `UNUserNotificationCenterDelegate`.

**After (Fixed):**
- AppDelegate now explicitly conforms to `UNUserNotificationCenterDelegate`
- Added `userNotificationCenter(_:willPresent:withCompletionHandler:)` to show notifications in foreground
- Added `userNotificationCenter(_:didReceive:withCompletionHandler:)` to handle notification taps
- Added `application.registerForRemoteNotifications()` for explicit registration

---

### ✅ Issue 2: Wrong APNS Payload Key in Cloud Functions (index.js)

**Before (Broken):**
```javascript
aps: {
  contentAvailable: true,  // ❌ WRONG - JavaScript camelCase
}
```

**After (Fixed):**
```javascript
aps: {
  "content-available": 1,     // ✅ iOS expects hyphenated key with integer value
  "mutable-content": 1,       // ✅ Allow notification modification
  "thread-id": "bus_arrival", // ✅ Group notifications
  "interruption-level": "time-sensitive", // ✅ Break through Focus mode
}
```

Also added:
- `"apns-push-type": "alert"` header for explicit notification type

---

### ✅ Issue 3: APNS Environment Set to "development" (Runner.entitlements)

**Before:**
```xml
<key>aps-environment</key>
<string>development</string>
```

**After:**
```xml
<key>aps-environment</key>
<string>production</string>
```

This is **critical** for App Store/TestFlight builds. The entitlement must match the APNS certificate type in Firebase.

---

### ✅ Issue 4: Missing APNS Token Retrieval Before FCM Token (main.dart & auth_login.dart)

**iOS Requirement:** APNS token must be available before FCM can work.

**Added in main.dart:**
```dart
if (Platform.isIOS) {
  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken == null) {
    await Future.delayed(const Duration(seconds: 2));
    apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  }
}
```

**Added in auth_login.dart:**
```dart
if (!kIsWeb && Platform.isIOS) {
  String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken == null) {
    await Future.delayed(const Duration(seconds: 2));
    apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  }
}
fcmToken = await FirebaseMessaging.instance.getToken();
```

---

### ✅ Issue 5: Enhanced iOS Notification Permissions (main.dart)

**Added additional permissions:**
```dart
FirebaseMessaging.instance.requestPermission(
  alert: true,
  badge: true,
  sound: true,
  criticalAlert: true,    // ✅ For time-sensitive bus arrival notifications
  provisional: false,
  announcement: true,     // ✅ Announce notifications via Siri
  carPlay: true,          // ✅ Show notifications in CarPlay
);
```

---

## Files Modified

| File | Changes |
|------|---------|
| `busmate_app/ios/Runner/AppDelegate.swift` | Full UNUserNotificationCenterDelegate implementation |
| `busmate_app/ios/Runner/Runner.entitlements` | Changed aps-environment to "production" |
| `busmate_app/functions/index.js` | Fixed APNS payload with correct keys |
| `busmate_app/lib/main.dart` | Added APNS token retrieval and enhanced permissions |
| `busmate_app/lib/meta/firebase_helper/auth_login.dart` | Added APNS token retrieval before FCM token |

---

## Deployment Status

✅ **Cloud Functions deployed successfully** (firebase deploy --only functions)

---

## Required Actions

### 1. Rebuild iOS App
```bash
cd busmate_app
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
flutter build ios --release
```

### 2. Verify Firebase Console Settings
Ensure you have:
- ✅ APNS **Production** certificate or key uploaded in Firebase Console
- ✅ OR Apple Auth Key (.p8) for APNS configured
- Path: Firebase Console → Project Settings → Cloud Messaging → iOS app configuration

### 3. Test on Real iOS Device
- Background notifications require testing on a **real device** (not simulator)
- Ensure the app has notification permissions granted
- Check iOS Settings → Notifications → BusMate → Allow Notifications = ON

---

## Debugging Tips

### Check if APNS Token is being retrieved:
Look for this log in Xcode console:
```
✅ iOS APNS Token: Available
```

If it says "NOT Available", the issue is with APNS configuration.

### Check Firebase Console for delivery errors:
Firebase Console → Cloud Messaging → Reports → Check for iOS delivery failures

### Common iOS Notification Issues:
1. **Focus Mode** - Check if Focus/DND is blocking notifications
2. **Provisional Authorization** - User may have "Deliver Quietly" enabled
3. **Background App Refresh** - Must be enabled for background notifications
4. **Low Power Mode** - May delay background notifications

---

## Why Language Notifications Worked But GPS Didn't

Language setting notifications likely used a simpler notification payload that worked by accident, while GPS bus notifications used:
- Background processing (`contentAvailable`)
- Custom sound files
- Time-sensitive priority

These required the correct APNS payload format that iOS strictly enforces.
