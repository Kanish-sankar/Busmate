# 🧪 Test Notification Button - Quick Guide

## ✅ What Was Added

Two test buttons on the Home Screen:

### 1. **Test Voice Notification** (Orange Button)
- Plays Tamil voice notification
- Shows notification with sound
- Tests the actual voice file that will be used

### 2. **Test Silent Notification** (Gray Button)
- Shows notification without sound
- Tests text-only notification

## 📱 How to Test

### Step 1: Run the App
```bash
cd "c:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app"
flutter run -d <device>
```

### Step 2: Navigate to Home Screen
1. Login as a parent/student
2. You'll see the home screen with student details
3. Scroll down - you'll see two test buttons

### Step 3: Test Voice Notification
1. Tap **"Test Voice Notification"** (Orange button)
2. A snackbar appears: "Voice notification sent!"
3. Check your notification tray
4. **You should hear Tamil voice saying the notification message**
5. Notification shows: "🚍 Bus Approaching! (Test)"
6. Body: "This is a test notification. The bus will arrive in approximately 8 minutes."

### Step 4: Test Silent Notification
1. Tap **"Test Silent Notification"** (Gray button)
2. A snackbar appears: "Silent notification sent!"
3. Check your notification tray
4. **No voice should play - just a standard notification**
5. Same message but without sound

## 🔍 What This Tests

### ✅ Voice Notification Testing:
1. **notification_tamil.wav file exists and loads correctly**
2. **Android notification channel configured with sound**
3. **iOS notification categories working**
4. **Sound plays on notification receive**
5. **Notification appears in tray with proper formatting**

### ✅ Silent Notification Testing:
1. **Text-only notifications work**
2. **No sound plays when isVoice=false**
3. **Notification still shows with same priority**

## 🎯 Expected Results

### On Android:
- **Voice Notification**: Tamil voice plays automatically when notification appears
- **Silent Notification**: Standard notification sound (or silent)
- Both show in notification tray with "Acknowledge" action button

### On iOS:
- **Voice Notification**: Tamil voice plays when notification received
- **Silent Notification**: No sound plays
- Both appear as banner notifications

## 🐛 Troubleshooting

### Issue: No Sound Playing

**Check 1: Notification Permissions**
- Go to Settings → Apps → Busmate → Notifications
- Ensure notifications are enabled
- Check "Busmate Notifications" channel has sound enabled

**Check 2: Device Volume**
- Make sure media volume is up (not just ringer volume)
- Test with device unmuted

**Check 3: File Exists**
```bash
# Verify Tamil voice file exists
android/app/src/main/res/raw/notification_tamil.wav ✅
ios/Runner/notification_tamil.wav ✅
```

**Check 4: App Logs**
```bash
flutter logs
# Look for notification-related messages
```

### Issue: Notification Not Appearing

**Check:** App Notification Permissions
- First time: App will ask for notification permission
- If denied: Go to Settings → Apps → Busmate → Enable notifications

**Check:** Notification Initialization
- NotificationHelper.initialize() should run in main()
- Check main.dart has this call

### Issue: App Crashes on Button Tap

**Check:** Import Statement
- Verify notification_helper.dart is imported in home_screen.dart
- Should see: `import 'package:busmate/meta/firebase_helper/notification_helper.dart';`

## 📊 Success Criteria

✅ **Voice notification plays Tamil voice file**  
✅ **Silent notification shows without sound**  
✅ **Both notifications appear in tray**  
✅ **Acknowledge button works on Android**  
✅ **Snackbar appears after button tap**  
✅ **No app crashes or errors**

## 🎬 Demo Flow

```
1. Open App
   ↓
2. Login → Home Screen
   ↓
3. Tap "Test Voice Notification"
   ↓
4. Hear Tamil Voice 🔊
   ↓
5. See Notification in Tray
   ↓
6. Tap "Test Silent Notification"
   ↓
7. No Sound (Silent) 🔕
   ↓
8. See Notification in Tray
   ↓
SUCCESS! ✅
```

## 📍 Where to Find the Buttons

**Location:** Home Screen (Parent Module)  
**Path:** Dashboard → Home Tab → Scroll Down  
**After:** Student Details Card  
**Before:** Commented Logout Button

## 🔄 Next Steps After Testing

Once you confirm:
1. ✅ Tamil voice plays correctly
2. ✅ Notification appears properly
3. ✅ Sound quality is good

Then the production notification system will work the same way when:
- Bus ETA reaches student's preference time
- Cloud Function sends FCM notification
- App receives and plays Tamil voice automatically

---

**Location of Changes:**
- `lib/meta/firebase_helper/notification_helper.dart` - Added `showTestNotification()` function
- `lib/presentation/parents_module/dashboard/screens/home_screen.dart` - Added two test buttons

**Ready to Test!** 🚀
