#!/bin/bash
# Compila o Faxina e monta o bundle .app. Sem dependências além do toolchain Swift.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Faxina"
BUNDLE_ID="dev.local.faxina"
VERSION="1.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "▸ Compilando (release, universal)…"
swift build -c release --arch arm64 --arch x86_64

echo "▸ Montando bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/apple/Products/Release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

echo "▸ Gerando ícone…"
ICONSET="$BUILD_DIR/$APP_NAME.iconset"
rm -rf "$ICONSET"
if swift make-icon.swift "$ICONSET" >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/$APP_NAME.icns"
    ICON_KEY="<key>CFBundleIconFile</key><string>$APP_NAME</string>"
else
    echo "  (ícone falhou; seguindo sem ele)"
    ICON_KEY=""
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    $ICON_KEY
</dict>
</plist>
PLIST

# Assinatura ad-hoc: suficiente para rodar localmente e para o macOS lembrar
# a concessão de Acesso Total ao Disco entre execuções.
echo "▸ Assinando (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP" 2>/dev/null

rm -rf "$ICONSET"
echo
echo "✓ $APP"
echo "  abrir:   open $APP"
echo "  instalar: cp -R $APP /Applications/"
