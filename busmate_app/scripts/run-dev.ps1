param(
  [string]$DefineFile = '.dart_define.dev.json'
)

if (-not (Test-Path $DefineFile)) {
  Write-Error "Define file not found: $DefineFile"
  Write-Host "Generate it first: ./scripts/setup-dev-defines.ps1 -Target android" -ForegroundColor Yellow
  exit 1
}

flutter run -t lib/main_dev.dart --dart-define-from-file=$DefineFile
