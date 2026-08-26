#!/bin/bash
set -e

echo "=== Installing Flutter SDK for Vercel Build ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

echo "=== Checking Flutter Version ==="
flutter --version

echo "=== Resolving Dependencies ==="
flutter pub get

echo "=== Building Flutter Web Production App ==="
flutter build web --release

echo "=== Build Complete! Output at build/web ==="
