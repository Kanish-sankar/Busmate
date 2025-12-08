# 🔔 Busmate Complete Notification System Documentation

## Overview
Comprehensive voice and text notification system for alerting parents when the school bus is approaching their child's stop.

## ✅ Deployed Components

### 1. **Cloud Functions (Firebase)**
All functions successfully deployed to `busmate-b80e8` project.

#### **sendBusArrivalNotifications**
- **Schedule**: Every 2 minutes
- **Purpose**: Check students with `notified=false` and send FCM notifications when ETA ≤ preference time
- **Features**:
  - Batch processing (100 students per run)
  - Groups students by bus ID to minimize Realtime DB queries
  - Supports both Voice and Text notifications
  - Duplicate prevention (won't notify if ETA changed <2 minutes)
  - Tracks `lastNotifiedRoute` for direction-specific notifications
  - Updates Firestore with `notified=true` and `lastNotifiedAt` timestamp

#### **resetStudentNotifiedStatus**
- **Schedule**: Every 15 minutes (`*/15 * * * *`)
- **Purpose**: Reset `notified=false` when trip schedule starts
- **Features**:
  - Checks route schedules from Firestore
  - Compares current time with `startTime` (±15 minute window)
  - Validates day of week matches schedule
  - Resets only for the current trip direction (pickup/drop)
  - Allows separate notifications for morning pickup and afternoon drop

### 2. **Voice Notification Files**
- **Current Setup**: Using `notification_tamil.wav` for ALL languages temporarily
- **Location (Android)**: `android/app/src/main/res/raw/notification_tamil.wav`
- **Location (iOS)**: `ios/Runner/notification_tamil.wav`
- **Future**: Replace with language-specific files when ready

### 3. **App-Side Implementation**

#### **notification_helper.dart**
Complete implementation with:
- FCM initialization and permission requests
- Android notification channels (sound + silent)
- iOS notification categories and sound support
- `getSoundName()` - Currently returns "notification_tamil" for all languages
- `showCustomNotification()` - Handles voice vs text notifications
- Foreground, background, and terminated message handling

## 🎯 Notification Flow

### Step 1: Bus Location Update (Every 3 seconds)
```
GPS Simulator → onBusLocationUpdate → Realtime DB
└─ Updates: currentLocation, remainingStops[], estimatedMinutesOfArrival
```

### Step 2: Notification Check (Every 2 minutes)
```
sendBusArrivalNotifications
├─ Query Firestore: notified=false, fcmToken!=null
├─ Group by assignedBusId
├─ For each bus:
│  ├─ Get bus status from Realtime DB
│  ├─ Find stop ETA for each student
│  ├─ If ETA ≤ notificationPreferenceByTime:
│  │  ├─ Check duplicate prevention (lastNotifiedETAs)
│  │  ├─ Build FCM payload with sound based on notificationType
│  │  └─ Send notification + update Firestore
│  └─ Update: notified=true, lastNotifiedRoute, lastNotifiedAt
```

### Step 3: Trip-Based Reset (Every 15 minutes)
```
resetStudentNotifiedStatus
├─ Get all bus_locations from Realtime DB
├─ For each bus:
│  ├─ Get route_schedules from Firestore
│  ├─ Calculate time difference: currentTime - startTime
│  ├─ If within ±15 min window AND correct day of week:
│  │  ├─ Get all students on this bus
│  │  ├─ If lastNotifiedRoute != currentDirection:
│  │  │  └─ Reset: notified=false, lastNotifiedRoute=null
│  └─ Batch commit all resets
```

## 📊 Data Structure

### Student Document (Firestore)
```javascript
{
  studentId: "S12345",
  name: "John Doe",
  schoolId: "SCH001",
  assignedBusId: "BUS123",
  stopLocation: "Main Street",
  fcmToken: "fCmT0k3n...",
  notificationType: "Voice Notification", // or "Text Notification"
  languagePreference: "tamil",
  notificationPreferenceByTime: 10, // Minutes before arrival
  notified: false, // Reset when trip starts
  lastNotifiedRoute: "pickup", // or "drop"
  lastNotifiedAt: Timestamp
}
```

### Bus Status (Realtime Database)
```javascript
{
  "bus_locations": {
    "SCH001": {
      "BUS123": {
        isActive: true,
        activeRouteId: "ROUTE456",
        tripDirection: "pickup", // or "drop"
        currentLocation: { lat: 12.34, lng: 56.78 },
        remainingStops: [
          {
            name: "Main Street",
            estimatedMinutesOfArrival: 8.5,
            estimatedTimeOfArrival: Timestamp
          }
        ],
        lastNotifiedETAs: {
          "Main Street": Timestamp
        }
      }
    }
  }
}
```

### Route Schedule (Firestore)
```javascript
{
  routeId: "ROUTE456",
  routeName: "Route A - Morning",
  startTime: "07:00", // HH:MM format
  endTime: "09:00",
  daysOfWeek: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
  direction: "pickup" // or "drop"
}
```

## 🔊 Voice Notification Configuration

### Current Implementation
```dart
// App-side (notification_helper.dart)
static String getSoundName(String language) {
  return "notification_tamil"; // Temporary for all languages
}
```

```javascript
// Cloud Function (index.js)
function getSoundName(language) {
  return "notification_tamil"; // Temporary for all languages
}
```

### FCM Payload Structure
```javascript
{
  notification: {
    title: "Bus Approaching!",
    body: "Bus will arrive in approximately 8 minutes."
  },
  android: {
    notification: {
      channelId: "busmate",
      sound: "notification_tamil", // .wav auto-appended
      visibility: "public",
      clickAction: "FLUTTER_NOTIFICATION_CLICK"
    }
  },
  apns: {
    payload: {
      aps: {
        alert: { title: "...", body: "..." },
        sound: "notification_tamil.wav", // Explicit .wav extension
        badge: 1
      }
    }
  },
  data: {
    type: "bus_arrival",
    studentId: "S12345",
    notificationType: "Voice Notification",
    selectedLanguage: "tamil",
    eta: "8",
    busId: "BUS123"
  }
}
```

## 🚀 Deployment Status

### ✅ Successfully Deployed
- [x] `sendBusArrivalNotifications` - Updated with Tamil sound for all languages
- [x] `resetStudentNotifiedStatus` - Trip-based reset every 15 minutes
- [x] `onBusLocationUpdate` - ETA calculation with segment-based recalculation
- [x] Deleted `resetNotificationsOnRouteChange` (replaced by trip-based reset)

### 📱 App Configuration
- [x] `notification_helper.dart` - Updated to use Tamil for all languages
- [x] Android notification channels configured
- [x] iOS notification categories configured
- [x] FCM permission requests implemented
- [x] Foreground/background/terminated message handlers ready

## 🧪 Testing Checklist

### 1. Voice Notification Test
- [ ] Set student `notificationType` = "Voice Notification"
- [ ] Set student `languagePreference` = "tamil" (or any language)
- [ ] Ensure `notification_tamil.wav` exists in `android/app/src/main/res/raw/`
- [ ] Ensure `notification_tamil.wav` exists in `ios/Runner/`
- [ ] Start bus trip and wait for ETA ≤ preference time
- [ ] Verify Tamil voice plays on notification

### 2. Trip-Based Reset Test
- [ ] Set up route schedule with `startTime` = "14:00", `direction` = "pickup"
- [ ] Student gets notified at 13:50 (morning drop)
- [ ] Verify `notified=true`, `lastNotifiedRoute="drop"`
- [ ] Wait until 14:00 (afternoon pickup starts)
- [ ] At 14:00-14:15, `resetStudentNotifiedStatus` should run
- [ ] Verify student reset: `notified=false`, `lastNotifiedRoute=null`
- [ ] Student should receive new notification for afternoon pickup

### 3. Duplicate Prevention Test
- [ ] Student at stop with ETA = 10 minutes
- [ ] First notification sent → `notified=true`
- [ ] ETA recalculates to 9.5 minutes (change < 2 min)
- [ ] Verify NO second notification (duplicate prevention)
- [ ] ETA recalculates to 7 minutes (change ≥ 2 min)
- [ ] Verify new notification IS sent

### 4. Direction Tracking Test
- [ ] Morning pickup at 07:00 → Student notified → `lastNotifiedRoute="pickup"`
- [ ] Afternoon drop at 15:00 → Different trip → Reset triggers → New notification
- [ ] Verify both notifications sent for same day, different directions

## 📝 Future Enhancements

### Language-Specific Voice Files (When Ready)
Update `getSoundName()` to return language-specific files:

```dart
// App-side
static String getSoundName(String language) {
  switch (language.toLowerCase()) {
    case "english": return "notification_english";
    case "hindi": return "notification_hindi";
    case "tamil": return "notification_tamil";
    case "telugu": return "notification_telugu";
    case "kannada": return "notification_kannada";
    case "malayalam": return "notification_malayalam";
    default: return "notification_english";
  }
}
```

### Create Elongated Voice Files (15 seconds)
Current files are short (2-5 sec). Create detailed messages:

**Example Tamil Script (15 seconds):**
```
உங்கள் குழந்தையின் பள்ளி பேருந்து இப்போது அருகில் உள்ளது. 
சுமார் [X] நிமிடங்களில் பேருந்து நிலையத்தை அடையும். 
தயவுசெய்து தயாராக இருங்கள்.
```

**English Equivalent:**
```
Your child's school bus is now approaching. 
The bus will reach the stop in approximately [X] minutes. 
Please be ready at the pickup point.
```

### Dynamic ETA in Voice (Future)
Generate voice files with specific ETA values:
- `notification_tamil_5min.wav` - "5 நிமிடங்களில்"
- `notification_tamil_10min.wav` - "10 நிமிடங்களில்"
- `notification_tamil_15min.wav` - "15 நிமிடங்களில்"

## 🔍 Monitoring & Logs

### View Cloud Function Logs
```bash
firebase functions:log --only resetStudentNotifiedStatus
firebase functions:log --only sendBusArrivalNotifications
```

### Key Log Messages
- `🔄 Checking trip schedules for notification resets...` - Reset function triggered
- `🚀 Trip starting for bus [busId]` - Trip schedule matched
- `✅ Resetting notification for [student]` - Student reset
- `🚍 Queuing notification for [student] (ETA: Xmin)` - Notification about to send
- `⏭️ Skipping notification - already notified` - Duplicate prevention working
- `🔔 ETA changed by X min - allowing notification` - ETA changed significantly

## 📞 Support & Troubleshooting

### Notifications Not Sending
1. Check `notified=false` in Firestore
2. Verify `fcmToken` exists for student
3. Verify bus `isActive=true` in Realtime DB
4. Check ETA ≤ `notificationPreferenceByTime`
5. View Cloud Function logs for errors

### Voice Not Playing
1. Verify `notificationType="Voice Notification"` (case-sensitive)
2. Check `notification_tamil.wav` exists in Android/iOS folders
3. Verify Android notification channel created with sound
4. Check iOS sound file has `.wav` extension in payload

### Reset Not Working
1. Verify route schedule exists in Firestore
2. Check `startTime` format is "HH:MM"
3. Verify `daysOfWeek` includes current day
4. Check Cloud Function runs every 15 minutes
5. View logs for "Trip starting" messages

---

**Last Updated**: December 3, 2025  
**Deployed Version**: All functions live on Firebase  
**Status**: ✅ Production Ready with Tamil voice for all languages
