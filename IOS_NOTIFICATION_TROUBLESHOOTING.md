# iOS Notification Troubleshooting Guide

## Issue Identified

The iOS student document shows `platform: "android"` even though it's an iOS device. This happens because the platform field wasn't being updated when FCM tokens are saved.

## Fix Applied

**File: [auth_login.dart](busmate_app/lib/meta/firebase_helper/auth_login.dart#L467-L472)**

Added platform detection when updating FCM tokens:
```dart
// Detect platform
String platformName = 'unknown';
if (!kIsWeb) {
  if (Platform.isIOS) {
    platformName = 'ios';
  } else if (Platform.isAndroid) {
    platformName = 'android';
  }
}

final updateData = <String, dynamic>{
  'fcmToken': token,
  'platform': platformName,  // ✅ Now tracking device platform
  'tokenUpdatedAt': FieldValue.serverTimestamp(),
};
```

## Steps to Test iOS Notifications

### 1. Update iOS App
- Rebuild and reinstall the app on the iOS device
- The new code will correctly set `platform: 'ios'` when the FCM token is saved

### 2. Force Token Refresh
On the iOS device:
1. **Log out** of the app completely
2. **Log back in** with the student account
3. Verify in Firestore that the student document now shows:
   - `platform: "ios"` ✅ (not "android")
   - `tokenUpdatedAt: [current timestamp]`
   - `fcmToken: [starts with eMTHrKP-YUU...]`

### 3. Check Firebase Cloud Functions Logs

Go to Firebase Console → Functions → Logs and search for the iOS student during a trip:

**Expected Logs for iOS Student:**

```
🚀 ============================================
🚀 SENDING FCM to [studentId] (ABC)
📱 Token: eMTHrKP-YUU0nUfv-vZTPf:APA91b...
📦 Payload:
   - Title: Bus Approaching!
   - Body: Bus will arrive in approximately X minutes.
   - Android: DATA-ONLY message (no notification field)
   - iOS: notification + data
   - Language: tamil
✅ ============================================
✅ FCM SEND SUCCESS for [studentId] (ABC)
✅ Message ID: [message_id]
```

**If you see errors like:**
```
❌ FCM SEND FAILED for [studentId] (ABC)
❌ Error code: messaging/invalid-registration-token
```

This means the FCM token is invalid/expired. Solutions:
- Uninstall and reinstall the app
- Clear app data
- Check iOS notification permissions

### 4. Check iOS Notification Permissions

On the iOS device:
1. Go to **Settings → [App Name] → Notifications**
2. Verify these are enabled:
   - ✅ Allow Notifications
   - ✅ Sounds
   - ✅ Badges
   - ✅ Show in Notification Center
   - ✅ Show on Lock Screen

3. Check **Do Not Disturb** is OFF
4. Check **Focus Mode** is not blocking notifications

### 5. Check iOS APNs Configuration

In Firebase Console:
1. Go to **Project Settings → Cloud Messaging → iOS app**
2. Verify:
   - ✅ APNs Authentication Key is uploaded (or APNs Certificates)
   - ✅ Team ID is correct
   - ✅ Key ID is correct
   - ✅ Bundle ID matches your app

### 6. Verify Notification Threshold

Check if the student's notification preference is being met:
- iOS student has `notificationPreferenceByTime: 30` (wants notification 30 minutes before)
- Android student has `notificationPreferenceByTime: 30`

If the bus ETA is **31 minutes**, neither will get notified yet (waiting for ETA ≤ 30 min).

### 7. Compare Students Side-by-Side

| Field | Android (WORKING) | iOS (NOT WORKING) | Action |
|-------|-------------------|-------------------|--------|
| `platform` | "android" ✅ | "android" ❌ | Force re-login on iOS |
| `fcmToken` | Valid | Valid | Check if token works |
| `notified` | `true` | `false` | Check Cloud Function logs |
| `lastNotifiedAt` | Feb 22 12:21 PM | `null` | Never received notification |
| `lastNotifiedTripId` | Valid | `null` | Never notified for this trip |
| `lastNotifiedRoute` | "pickup" ✅ | "0Qui8IL10w2t5RCLbOVk" ❌ | Old/corrupted data |
| `notificationType` | "Voice Notification" | "Text Notification" | iOS using text instead of voice |

**Issues Found:**
1. ❌ `platform: "android"` on iOS device → **FIXED in code, needs re-login**
2. ❌ `lastNotifiedRoute: "0Qui8IL10w2t5RCLbOVk"` → Old data (should be "pickup"/"drop")
3. ⚠️ `notificationType: "Text Notification"` → iOS student not using voice notifications

### 8. Test Notification Manually

You can test if the FCM token works by using Firebase Console:
1. Go to **Firebase Console → Engage → Messaging**
2. Click **"Send your first message"**
3. Enter test notification title and text
4. Click **Next → Send test message**
5. Enter the iOS student's FCM token: `eMTHrKP-YUU0nUfv-vZTPf:APA91b...`
6. Click **Test**

If this test notification arrives on iOS:
- ✅ Token is valid, APNs is configured correctly
- ❌ Issue is in Cloud Function logic or trip criteria

If test notification doesn't arrive:
- ❌ Token is invalid/expired → Reinstall app and get new token
- ❌ APNs not configured → Check Firebase iOS setup

## Common iOS Notification Issues

### Issue 1: Silent Notifications (No Sound)
**Symptoms:** Notification appears but no sound plays

**Causes:**
- Sound file not found in iOS bundle
- Sound file format wrong (must be `.wav`)
- iOS Do Not Disturb mode enabled

**Solution:**
- Verify sound files in `ios/Runner/Resources/` (e.g., `notification_tamil.wav`)
- Check sound file format: must be `.wav`, max 30 seconds, mono/stereo, 16-bit
- Disable Do Not Disturb

### Issue 2: No Notification at All
**Symptoms:** Nothing appears on lock screen or notification center

**Causes:**
- App permissions denied
- Invalid FCM token
- APNs certificate issue
- App in foreground (notifications suppressed)

**Solution:**
- Grant notification permissions in Settings
- Force re-login to get new token
- Check APNs configuration in Firebase
- Test with app in background/killed

### Issue 3: Delayed Notifications
**Symptoms:** Notification arrives 5-10 minutes late

**Causes:**
- iOS background app refresh disabled
- Low Power Mode enabled
- Apple server delays (APNs)

**Solution:**
- Enable Background App Refresh in iOS Settings
- Disable Low Power Mode
- Set `apns-priority: 10` in Cloud Function (already done)

## Quick Diagnostic Commands

### Check if iOS student is being processed by Cloud Function:
Look for this in Cloud Function logs:
```
👤 Processing ABC at "Stop 1"
📊 ETA: X min, Preference: 30 min
```

If you don't see this log:
- Student might be filtered out before processing
- Check `fcmToken` exists
- Check `stopping` matches route stops
- Check `notificationPreferenceByTime` is a valid number

### Check if notification was sent:
Look for:
```
✅ FCM SEND SUCCESS for [studentId] (ABC)
✅ Message ID: [message_id]
```

If you see this but iOS device doesn't receive:
- Token is accepted by FCM but Apple rejected delivery
- Check iOS device notification settings
- Check APNs certificate expiration
- Try reinstalling the app

## Next Steps

1. **Immediate:** Force re-login on iOS device to update platform field
2. **Check:** Cloud Function logs during next trip to see if notification is sent
3. **Test:** Send manual test notification from Firebase Console to verify token
4. **Compare:** Check why iOS student has "Text Notification" instead of "Voice Notification"
5. **Verify:** Ensure iOS sound files are in the app bundle

## Files Modified

- [auth_login.dart](busmate_app/lib/meta/firebase_helper/auth_login.dart) - Added platform detection when saving FCM token
