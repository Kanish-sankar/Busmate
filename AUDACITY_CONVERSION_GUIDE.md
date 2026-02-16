# Audio Conversion Guide for Windows - Audacity

## Quick 5-Minute Process

### 1. Download & Install Audacity
- Go to: https://www.audacityteam.org/download/
- Click "Download Audacity" for Windows
- Install (accept defaults)

### 2. Navigate to Audio Files
Open File Explorer:
```
C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app\ios\Runner
```

You'll see 6 files:
- notification_english.wav
- notification_hindi.wav
- notification_kannada.wav
- notification_malayalam.wav
- notification_tamil.wav
- notification_telugu.wav

### 3. Convert EACH File (Repeat 6 times)

**For EACH wav file:**

1. **Open in Audacity:**
   - File → Open
   - Select notification_english.wav (first file)

2. **Convert to Mono:**
   - Click track dropdown (left side, says "Stereo")
   - Select: "Split Stereo to Mono"
   - Delete the bottom track (right-click → Remove Track)

3. **Change Sample Rate:**
   - Click track dropdown again
   - Select: "Rate" → "22050 Hz"

4. **Export as CAF:**
   - File → Export → Export Audio
   - Format: "Other uncompressed files"
   - Click "Options" button
   - Header: "CAF (Core Audio File)"
   - Encoding: "IMA ADPCM" (this is IMA4)
   - File name: `notification_english.caf` (change extension!)
   - Location: Same folder (ios/Runner)
   - Click "Save"

5. **Repeat for remaining 5 files**
   - notification_hindi.wav → notification_hindi.caf
   - notification_kannada.wav → notification_kannada.caf
   - notification_malayalam.wav → notification_malayalam.caf
   - notification_tamil.wav → notification_tamil.caf
   - notification_telugu.wav → notification_telugu.caf

### 4. Delete Old WAV Files
After confirming all 6 .caf files are created:
```powershell
cd "C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate\busmate_app\ios\Runner"
Remove-Item notification_*.wav
```

### 5. Verify New File Sizes
```powershell
Get-ChildItem notification_*.caf | Select-Object Name, @{Name="Size (KB)";Expression={[math]::Round($_.Length/1KB, 2)}}
```

**Expected:** 150-250 KB each (down from 937 KB!)

### 6. Update Xcode Project
The .caf files need to be added to Xcode:

**If you have a Mac:**
1. Open `busmate_app/ios/Runner.xcodeproj` in Xcode
2. Delete old .wav file references (select and press Delete)
3. Right-click Runner folder → Add Files to "Runner"
4. Select all 6 .caf files
5. Check "Copy items if needed"
6. Ensure "Runner" target is checked
7. Click "Add"

**If you DON'T have a Mac:**
- Codemagic will rebuild the project and include the .caf files automatically
- Just commit and push the files to GitHub

### 7. Commit & Push
```powershell
cd "C:\Users\kanis\OneDrive\Desktop\Jupenta Codes Final\jupenta-busmate"
git add busmate_app/ios/Runner/notification_*.caf
git add busmate_app/lib/meta/firebase_helper/notification_helper.dart
git add busmate_app/functions/index.js
git commit -m "Fix: iOS notification audio - compressed to CAF format (22.05kHz mono IMA4)"
git push origin main
```

### 8. Deploy Functions
```powershell
cd "busmate_app/functions"
npm run build
cd ..
firebase deploy --only functions:onBusLocationUpdate
```

### 9. Rebuild iOS on Codemagic
Start new build - full 30-second audio will now play!

## Troubleshooting

**"Can't find IMA ADPCM in Audacity":**
- Use "Signed 16-bit PCM" instead
- File will be slightly larger (~300-400 KB) but still works

**"Export as CAF not showing":**
- Make sure you selected "Other uncompressed files" as format
- Then Header dropdown will show "CAF"

**"File size still large":**
- Verify you changed to 22050 Hz
- Verify you're using mono (only 1 track shown)
- IMA ADPCM gives best compression
