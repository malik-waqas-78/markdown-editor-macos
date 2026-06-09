#!/bin/bash
# Builds MarkdownEditor.app — a self-contained, installable macOS app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Markdown Editor"
EXEC_NAME="MarkdownEditor"
BUNDLE_ID="com.citizenknowledge.MarkdownEditor"
APP="build/${APP_NAME}.app"

echo "▸ Compiling (release)…"
swift build -c release

BIN=".build/release/${EXEC_NAME}"
RES_BUNDLE=".build/release/${EXEC_NAME}_${EXEC_NAME}.bundle"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/${EXEC_NAME}"
cp Info.plist "$APP/Contents/Info.plist"

# Copy the web resources straight into Resources/web so they load via Bundle.main
# (avoids the fragile Bundle.module accessor, which fatalErrors when unresolved).
cp -R "Sources/${EXEC_NAME}/Resources/web" "$APP/Contents/Resources/web"
# Also keep the SwiftPM resource bundle if present (harmless fallback).
[ -d "$RES_BUNDLE" ] && cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"

echo "▸ Generating icon…"
if swift make_icon.swift build/AppIcon.iconset >/dev/null 2>&1; then
    iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null \
        && echo "  icon ok" || echo "  (icon skipped)"
else
    echo "  (icon generation skipped)"
fi

echo "▸ Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP" 2>/dev/null && echo "  signed" || echo "  (sign skipped)"

echo "▸ Registering file associations with Launch Services…"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$(cd "$APP" && pwd)" 2>/dev/null || true

echo ""
echo "✅ Built: $APP"
echo "   Install:  cp -R \"$APP\" /Applications/"
echo "   Run:      open \"$APP\""
