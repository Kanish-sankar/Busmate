# busmate

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Safe Dev/Prod Workflow

This project is wired for two Firebase environments:

- `dev` -> `busmate-dev`
- `prod` -> `busmate-b80e8`

### App entrypoints

- Production entrypoint: `lib/main_prod.dart`
- Development entrypoint: `lib/main_dev.dart`

Background GPS callbacks now follow the same selected environment.

### Firebase aliases

Defined in `.firebaserc`:

- `dev`
- `prod`

### Deploy Cloud Functions safely

From `busmate_app/functions`:

```bash
npm run deploy:dev
```

After testing passes:

```bash
npm run deploy:prod
```

### Set update-config safely

```bash
npm run set:version-config:dev
```

```bash
npm run set:version-config:prod
```

### Running the app

Production:

```bash
flutter run -t lib/main_prod.dart
```

Development requires `DEV_FIREBASE_*` dart-defines used by `lib/firebase_options_dev.dart`.
Example:

```bash
flutter run -t lib/main_dev.dart \
	--dart-define=DEV_FIREBASE_PROJECT_ID=busmate-dev \
	--dart-define=DEV_FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID \
	--dart-define=DEV_FIREBASE_STORAGE_BUCKET=YOUR_BUCKET \
	--dart-define=DEV_FIREBASE_DATABASE_URL=YOUR_RTDB_URL \
	--dart-define=DEV_FIREBASE_ANDROID_API_KEY=YOUR_ANDROID_API_KEY \
	--dart-define=DEV_FIREBASE_ANDROID_APP_ID=YOUR_ANDROID_APP_ID \
	--dart-define=DEV_FIREBASE_IOS_API_KEY=YOUR_IOS_API_KEY \
	--dart-define=DEV_FIREBASE_IOS_APP_ID=YOUR_IOS_APP_ID \
	--dart-define=DEV_FIREBASE_IOS_BUNDLE_ID=YOUR_IOS_BUNDLE_ID \
	--dart-define=DEV_FIREBASE_WEB_API_KEY=YOUR_WEB_API_KEY \
	--dart-define=DEV_FIREBASE_WEB_APP_ID=YOUR_WEB_APP_ID \
	--dart-define=DEV_FIREBASE_WINDOWS_API_KEY=YOUR_WINDOWS_API_KEY \
	--dart-define=DEV_FIREBASE_WINDOWS_APP_ID=YOUR_WINDOWS_APP_ID
```

### Automated local setup (recommended)

From `busmate_app` folder:

```powershell
./scripts/setup-dev-defines.ps1 -Target android
```

This generates `.dart_define.dev.json`.

Run dev app with one command:

```powershell
./scripts/run-dev.ps1
```

Or in VS Code launch configs:

- `BusMate Dev` (uses `.dart_define.dev.json`)
- `BusMate Prod`
