param(
  [ValidateSet('android','ios','web','windows','all')]
  [string]$Target = 'android',
  [string]$OutputFile = '.dart_define.dev.json'
)

function Read-RequiredValue {
  param(
    [string]$Key,
    [string]$Prompt
  )

  while ($true) {
    $value = Read-Host "$Prompt"
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      return $value.Trim()
    }
    Write-Host "Value required for $Key" -ForegroundColor Yellow
  }
}

$defines = @{}

$defines['DEV_FIREBASE_PROJECT_ID'] = Read-RequiredValue 'DEV_FIREBASE_PROJECT_ID' 'DEV Firebase projectId (example: busmate-dev)'
$defines['DEV_FIREBASE_MESSAGING_SENDER_ID'] = Read-RequiredValue 'DEV_FIREBASE_MESSAGING_SENDER_ID' 'DEV messagingSenderId'
$defines['DEV_FIREBASE_STORAGE_BUCKET'] = Read-RequiredValue 'DEV_FIREBASE_STORAGE_BUCKET' 'DEV storageBucket (example: busmate-dev.appspot.com)'
$defines['DEV_FIREBASE_DATABASE_URL'] = Read-RequiredValue 'DEV_FIREBASE_DATABASE_URL' 'DEV realtime DB URL (https://...default-rtdb.firebaseio.com)'

if ($Target -eq 'android' -or $Target -eq 'all') {
  $defines['DEV_FIREBASE_ANDROID_API_KEY'] = Read-RequiredValue 'DEV_FIREBASE_ANDROID_API_KEY' 'DEV Android apiKey'
  $defines['DEV_FIREBASE_ANDROID_APP_ID'] = Read-RequiredValue 'DEV_FIREBASE_ANDROID_APP_ID' 'DEV Android appId (1:...:android:...)'
}

if ($Target -eq 'ios' -or $Target -eq 'all') {
  $defines['DEV_FIREBASE_IOS_API_KEY'] = Read-RequiredValue 'DEV_FIREBASE_IOS_API_KEY' 'DEV iOS apiKey'
  $defines['DEV_FIREBASE_IOS_APP_ID'] = Read-RequiredValue 'DEV_FIREBASE_IOS_APP_ID' 'DEV iOS appId (1:...:ios:...)'
  $defines['DEV_FIREBASE_IOS_BUNDLE_ID'] = Read-RequiredValue 'DEV_FIREBASE_IOS_BUNDLE_ID' 'DEV iOS bundleId (example: com.jupenta.busmate.dev)'
}

if ($Target -eq 'web' -or $Target -eq 'all') {
  $defines['DEV_FIREBASE_WEB_API_KEY'] = Read-RequiredValue 'DEV_FIREBASE_WEB_API_KEY' 'DEV Web apiKey'
  $defines['DEV_FIREBASE_WEB_APP_ID'] = Read-RequiredValue 'DEV_FIREBASE_WEB_APP_ID' 'DEV Web appId (1:...:web:...)'
}

if ($Target -eq 'windows' -or $Target -eq 'all') {
  $defines['DEV_FIREBASE_WINDOWS_API_KEY'] = Read-RequiredValue 'DEV_FIREBASE_WINDOWS_API_KEY' 'DEV Windows apiKey'
  $defines['DEV_FIREBASE_WINDOWS_APP_ID'] = Read-RequiredValue 'DEV_FIREBASE_WINDOWS_APP_ID' 'DEV Windows appId'
}

$json = $defines | ConvertTo-Json -Depth 3
Set-Content -Path $OutputFile -Value $json -Encoding UTF8

Write-Host "Created $OutputFile with $($defines.Keys.Count) dart-defines." -ForegroundColor Green
Write-Host "Run dev app: flutter run -t lib/main_dev.dart --dart-define-from-file=$OutputFile" -ForegroundColor Cyan
