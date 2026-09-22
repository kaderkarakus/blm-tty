#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP="$ROOT/BLM-TTY.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
BIN="$MACOS/BLM-TTY"

echo "==> BLM-TTY derleniyor"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$ROOT/Sources/App/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -f "$ROOT/LICENSE" ]; then
  cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
fi

LOGO="$ROOT/Sources/logo.png"
if [ ! -f "$LOGO" ]; then
  echo "logo.png bulunamadı: $LOGO" >&2
  exit 1
fi

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     "$LOGO" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$LOGO" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$LOGO" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$LOGO" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$LOGO" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$LOGO" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$LOGO" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$LOGO" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$LOGO" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$LOGO" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns -o "$RES/AppIcon.icns" "$ICONSET"
rm -rf "$(dirname "$ICONSET")"
echo "==> ikon: Sources/logo.png → $RES/AppIcon.icns"

ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macos13"
else
  TARGET="x86_64-apple-macos13"
fi

SDK="$(xcrun --show-sdk-path)"

SWIFT_SOURCES=()
while IFS= read -r f; do
  SWIFT_SOURCES+=("$f")
done <<EOF
$(find "$ROOT/Sources" -name '*.swift' | sort)
EOF

C_SOURCES=()
while IFS= read -r f; do
  C_SOURCES+=("$f")
done <<EOF
$(find "$ROOT/Sources" \( -name '*.c' -o -name '*.m' \) | sort)
EOF

echo "==> ${#SWIFT_SOURCES[@]} Swift, ${#C_SOURCES[@]} C, target $TARGET"

mkdir -p "$MACOS" "$RES"

swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -O \
  -swift-version 5 \
  -module-name BLMTTY \
  -I "$ROOT/Sources/Net" \
  -import-objc-header "$ROOT/Sources/Net/BLM-Bridging-Header.h" \
  -Xcc -fobjc-arc \
  -framework AppKit \
  -framework CryptoKit \
  -framework Network \
  -framework Security \
  -framework UniformTypeIdentifiers \
  -lutil \
  -o "$BIN" \
  "${C_SOURCES[@]}" \
  "${SWIFT_SOURCES[@]}"

chmod +x "$BIN"

# Xcode hesabındaki Apple Development kimliği (Keychain).
# Ad-hoc yalnızca açıkça: CODESIGN_IDENTITY=-
if [ "${CODESIGN_IDENTITY:-}" = "-" ]; then
  IDENTITY=""
elif [ -n "${CODESIGN_IDENTITY:-}" ]; then
  IDENTITY="$CODESIGN_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -n 1)"
fi
if [ -n "$IDENTITY" ] && security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null 2>&1; then
  echo "==> codesign (Xcode): $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" --timestamp=none "$APP"
elif [ "${CODESIGN_IDENTITY:-}" = "-" ]; then
  echo "==> codesign: ad-hoc (CODESIGN_IDENTITY=-)"
  codesign --force --deep --sign - "$APP"
else
  echo "Xcode Apple Development kimliği yok. Xcode → Settings → Accounts." >&2
  echo "Ad-hoc için: CODESIGN_IDENTITY=- $0" >&2
  exit 1
fi

echo "==> $APP hazır"

DIST="$ROOT/dist"
rm -rf "$DIST/BLM-TTY.app"
mkdir -p "$DIST"
ditto "$APP" "$DIST/BLM-TTY.app"
rm -f "$DIST/BLM-TTY-macos.zip"
ditto -c -k --keepParent "$DIST/BLM-TTY.app" "$DIST/BLM-TTY-macos.zip"
echo "==> dist: $DIST/BLM-TTY.app  $DIST/BLM-TTY-macos.zip"

if [ "${SKIP_OPEN:-0}" != "1" ]; then
  echo "==> açılıyor"
  open "$APP"
fi
