#!/usr/bin/env bash
set -euo pipefail

# Be resilient in case Vercel runs this from repo root.
if [ ! -f pubspec.yaml ] && [ -d busmate_web ]; then
  cd busmate_web
fi

git clone --depth 1 -b 3.32.8 https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release -t lib/main.dart
