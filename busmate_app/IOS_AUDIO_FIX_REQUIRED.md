# 🚨 iOS Audio File Issue - ACTION REQUIRED

## Problem
Current iOS notification audio files are **937 KB each** (uncompressed WAV format).
iOS is cutting them off at ~10 seconds due to improper format/size.

## Current Files Location
`busmate_app/ios/Runner/`
- notification_english.wav (937 KB)
- notification_hindi.wav (937 KB)
- notification_kannada.wav (937 KB)
- notification_malayalam.wav (937 KB)
- notification_tamil.wav (937 KB)
- notification_telugu.wav (937 KB)

## iOS Requirements
- **Maximum duration:** 30 seconds
- **Recommended file size:** < 300 KB
- **Preferred format:** CAF (Core Audio Format) with IMA4 codec
- **Alternative:** Linear PCM WAV at 22.05 kHz, mono
- **Sample rate:** 22,050 Hz (not 44,100 Hz)
- **Channels:** Mono (not stereo)

## Solution: Re-encode Audio Files

### Option A: Using Mac Terminal (Recommended)
```bash
cd busmate_app/ios/Runner

# Convert to Apple's optimized CAF format
afconvert -f caff -d ima4 -c 1 -r 22050 notification_english.wav notification_english.caf
afconvert -f caff -d ima4 -c 1 -r 22050 notification_hindi.wav notification_hindi.caf
afconvert -f caff -d ima4 -c 1 -r 22050 notification_kannada.wav notification_kannada.caf
afconvert -f caff -d ima4 -c 1 -r 22050 notification_malayalam.wav notification_malayalam.caf
afconvert -f caff -d ima4 -c 1 -r 22050 notification_tamil.wav notification_tamil.caf
afconvert -f caff -d ima4 -c 1 -r 22050 notification_telugu.wav notification_telugu.caf

# Delete old WAV files
rm notification_*.wav

# Rename CAF files back to WAV (or update code to use .caf)
# OR keep as .caf and update notification_helper.dart
```

### Option B: Using Audacity (Windows/Mac/Linux)
1. Open each WAV file in Audacity
2. **Convert to Mono:** Tracks → Mix → Mix Stereo Down to Mono
3. **Change Sample Rate:** Tracks → Resample → 22050 Hz
4. **Export:** File → Export → Export Audio
   - Format: WAV (Microsoft)
   - Encoding: Signed 16-bit PCM
   - File size should be ~150-200 KB

### Option C: Online Converter
1. Go to CloudConvert.com or similar
2. Upload WAV files
3. Convert to: WAV, 22050 Hz, Mono, 16-bit
4. Download and replace files

## After Re-encoding

### If Using .caf Files:
Update `notification_helper.dart` line 266:
```dart
sound: Platform.isIOS ? "$soundName.caf" : soundName,
```

Update `functions/index.js` line 1798:
```javascript
sound: `${soundName}.caf`, // iOS CAF format
```

### Update Xcode Project:
1. Delete old .wav files from Xcode project
2. Add new .caf files to Runner target
3. Verify in Build Phases → Copy Bundle Resources

## Testing
After fixing audio:
1. Build iOS app via Codemagic
2. Install on physical iPhone (iOS Simulator doesn't support push notifications)
3. Trigger notification
4. Verify full 30-second audio plays

## Expected Results
- File size: 150-250 KB each (down from 937 KB)
- Duration: Full 30 seconds
- Format: Optimized for iOS
- No cutoff at 10 seconds
