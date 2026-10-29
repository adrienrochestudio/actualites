#!/bin/bash
# Construit Actualités.app (universelle arm64 + x86_64), signée localement, et l'archive zip.
# Prévu pour un Mac avec les outils en ligne de commande Apple (runner GitHub macOS).
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build && mkdir -p build
APP="build/Actualités.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=(Sources/Modele.swift Sources/Textes.swift Sources/Depot.swift Sources/Vues.swift Sources/Globe.swift Sources/Zoom.swift Sources/Journal.swift Sources/MiseAJour.swift Sources/AppMac.swift)
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target "$arch-apple-macos13.0" "${SOURCES[@]}" -o "build/Actualites-$arch"
done
lipo -create build/Actualites-arm64 build/Actualites-x86_64 -output "$APP/Contents/MacOS/Actualites"

cp Info.plist "$APP/Contents/Info.plist"
# Version de l'app (commit) : comparée au lancement à mac-version.txt de la release pour la mise à jour automatique.
BUILD="${GITHUB_SHA:-$(git rev-parse HEAD)}"
BUILD="${BUILD:0:12}"
/usr/libexec/PlistBuddy -c "Add :ActualitesBuild string $BUILD" "$APP/Contents/Info.plist"
echo "$BUILD" > build/mac-version.txt
# Contours des terres pour le globe animé du logo (outils/terre.py).
cp ../geo/terre.json "$APP/Contents/Resources/terre.json"
mkdir -p "$APP/Contents/Resources/Fonts" && cp Fonts/*.ttf "$APP/Contents/Resources/Fonts/"

ICONES=build/Actualites.iconset
mkdir -p "$ICONES"
for t in 16 32 128 256; do
  sips -z $t $t icone-512.png --out "$ICONES/icon_${t}x${t}.png" >/dev/null
  sips -z $((t*2)) $((t*2)) icone-512.png --out "$ICONES/icon_${t}x${t}@2x.png" >/dev/null
done
cp icone-512.png "$ICONES/icon_512x512.png"
iconutil -c icns "$ICONES" -o "$APP/Contents/Resources/Actualites.icns"

codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Actualites-mac.zip
echo "OK : build/Actualites-mac.zip"
