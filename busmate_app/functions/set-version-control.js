const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function getProjectId() {
  if (process.env.GOOGLE_CLOUD_PROJECT) {
    return process.env.GOOGLE_CLOUD_PROJECT;
  }
  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }
  if (process.env.FIREBASE_PROJECT_ID) {
    return process.env.FIREBASE_PROJECT_ID;
  }

  try {
    const firebasercPath = path.resolve(__dirname, '..', '.firebaserc');
    if (fs.existsSync(firebasercPath)) {
      const firebaserc = JSON.parse(fs.readFileSync(firebasercPath, 'utf8'));
      if (firebaserc?.projects?.default) {
        return firebaserc.projects.default;
      }
    }
  } catch (_) {}

  return null;
}

const projectId = getProjectId();

if (!projectId) {
  console.error('❌ Could not determine Firebase project ID.');
  console.error(
    'Set GOOGLE_CLOUD_PROJECT or add projects.default in busmate_app/.firebaserc and retry.'
  );
  process.exit(1);
}

admin.initializeApp({ projectId });

function normalizePlayStoreUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') {
    return rawUrl;
  }

  try {
    const parsed = new URL(rawUrl.trim());
    const packageId = parsed.searchParams.get('id');

    if (!packageId) {
      return rawUrl.trim();
    }

    return `https://play.google.com/store/apps/details?id=${encodeURIComponent(
      packageId
    )}`;
  } catch (_) {
    return rawUrl.trim();
  }
}

async function run() {
  console.log(`Using Firebase project: ${projectId}`);
  const firestore = admin.firestore();
  const androidUrl = normalizePlayStoreUrl(
    process.env.UPDATE_URL_ANDROID ||
      'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_ID'
  );

  const config = {
    latest_version: '2.3.38',
    min_version_android: '2.3.37',
    min_version_ios: '2.3.37',
    force_update: false,
    force_update_message:
      'A critical update is required to continue using BusMate.',
    update_url_android: androidUrl,
    update_url_ios:
      process.env.UPDATE_URL_IOS ||
      'https://apps.apple.com/app/idYOUR_APP_ID',
    grace_days: 5,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await firestore
    .collection('app_config')
    .doc('version_control')
    .set(config, { merge: true });

  console.log('✅ app_config/version_control has been created/updated.');
  console.log('Config:', JSON.stringify(config, null, 2));
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Failed to set version control config:', error);
    if (String(error?.message || '').toLowerCase().includes('credentials')) {
      console.error(
        'Set GOOGLE_APPLICATION_CREDENTIALS to a service account key JSON and run again.'
      );
    }
    process.exit(1);
  });
