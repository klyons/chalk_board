#!/bin/bash
set -e

# Fix git safe directory for CI
git config --global --add safe.directory "*"

echo "=== Installing Flutter SDK for Vercel Build ==="
if [ ! -d "$HOME/_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/_flutter"
fi

export PATH="$PATH:$HOME/_flutter/bin"

echo "=== Flutter Doctor & Precache ==="
flutter precache --web
flutter --version

echo "=== Resolving Dependencies ==="
flutter pub get

echo "=== Building Flutter Web Production App ==="
flutter build web --release --no-tree-shake-icons

# Ensure build/web has index.html
if [ ! -f "build/web/index.html" ]; then
  echo "Error: build/web/index.html not generated!"
  exit 1
fi

echo "=== Build Complete! Output at build/web ==="
