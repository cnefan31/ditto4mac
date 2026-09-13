#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ditto4Mac"
OUTPUT_DIR="$PROJECT_ROOT/.build/release"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"

VERSION="${1:-$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")}"
VERSION="${VERSION#v}"

export APP_VERSION="$VERSION"
export APP_BUILD_VERSION="${APP_BUILD_VERSION:-${GITHUB_RUN_NUMBER:-$(date +%Y%m%d%H%M)}}"
if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
  echo "ERROR: set DEVELOPER_ID_APPLICATION, e.g."
  echo "  export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\""
  exit 1
fi

if [ "${SKIP_NOTARIZATION:-0}" = "1" ]; then
  echo "==> SKIP_NOTARIZATION=1, skip notarization"
else
  if [ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    : "${NOTARY_APPLE_ID:?set NOTARY_APPLE_ID or NOTARY_KEYCHAIN_PROFILE}"
    : "${NOTARY_TEAM_ID:?set NOTARY_TEAM_ID}"
    : "${NOTARY_PASSWORD:?set NOTARY_PASSWORD (app-specific password)}"
  fi
fi

echo "==> Building $APP_NAME $VERSION universal release"
APP_VERSION="$VERSION" APP_BUILD_VERSION="$APP_BUILD_VERSION" \
  bash "$PROJECT_ROOT/scripts/build_app.sh" release --universal

echo "==> Removing extended attributes"
xattr -cr "$APP_BUNDLE"

echo "==> Signing with Developer ID + hardened runtime"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
notarize() {
  local target="$1"
  if [ "${SKIP_NOTARIZATION:-0}" = "1" ]; then
    echo "==> SKIP_NOTARIZATION=1, skip notarization: $target"
    return 0
  fi
  if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    xcrun notarytool submit "$target" \
      --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
      --wait
  else
    xcrun notarytool submit "$target" \
      --apple-id "$NOTARY_APPLE_ID" \
      --team-id "$NOTARY_TEAM_ID" \
      --password "$NOTARY_PASSWORD" \
      --wait
  fi
}

APP_ZIP="$OUTPUT_DIR/$APP_NAME-$VERSION-app.zip"
rm -f "$APP_ZIP"
echo "==> Creating temporary app zip for notarization"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"

echo "==> Notarizing app"
notarize "$APP_ZIP"

if [ "${SKIP_NOTARIZATION:-0}" = "1" ]; then
  echo "==> SKIP_NOTARIZATION=1, skip stapling app"
else
  echo "==> Stapling app"
  xcrun stapler staple "$APP_BUNDLE"
fi

rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"

echo "==> Creating DMG"
DMG="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
TMP_DMG_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DMG_DIR"
}
trap cleanup EXIT

cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$TMP_DMG_DIR" \
  -ov -format UDZO \
  "$DMG"

echo "==> Signing DMG"
codesign --force --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$DMG"

echo "==> Notarizing DMG"
notarize "$DMG"

if [ "${SKIP_NOTARIZATION:-0}" = "1" ]; then
  echo "==> SKIP_NOTARIZATION=1, skip stapling DMG"
else
  echo "==> Stapling DMG"
  xcrun stapler staple "$DMG"
fi

echo "==> Verifying Gatekeeper acceptance"
spctl -a -vvv -t install "$APP_BUNDLE" || true
spctl -a -vvv -t open --context context:primary-signature "$DMG" || true

echo ""
echo "Release artifacts:"
echo "   DMG: $DMG"
echo "   ZIP: $APP_ZIP"
