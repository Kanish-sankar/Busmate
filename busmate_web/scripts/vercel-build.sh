#!/usr/bin/env bash
set -euo pipefail

# Be resilient in case Vercel runs this from repo root.
if [ ! -f pubspec.yaml ] && [ -d busmate_web ]; then
  cd busmate_web
fi

git clone -b 3.32.8 https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get --enforce-lockfile

if ! flutter build web --release -t lib/main.dart --web-renderer html 2>&1 | tee /tmp/flutter_build.log; then
  echo "---- Flutter build failed: extracted error lines ----"
  grep -nE "Error:|Exception:|Target file|Unhandled exception|Failed assertion" /tmp/flutter_build.log | tail -n 120 || true
  exit 1
fi
