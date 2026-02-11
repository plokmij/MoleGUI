#!/bin/bash
set -e

# MoleGUI Release Script
# Builds, signs, notarizes, and packages the app for distribution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/release"
APP_NAME="MoleGUI"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load config
CONFIG_FILE="$PROJECT_DIR/release.config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo_error "release.config not found!"
    echo_info "Copy release.config.example to release.config and fill in your details"
    exit 1
fi
source "$CONFIG_FILE"

# Validate config
if [ -z "$DEVELOPER_ID" ] || [ "$DEVELOPER_ID" = "Developer ID Application: Your Name (TEAMID)" ]; then
    echo_error "DEVELOPER_ID not set in release.config"
    exit 1
fi
if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" = "XXXXXXXXXX" ]; then
    echo_error "TEAM_ID not set in release.config"
    exit 1
fi
if [ -z "$APPLE_ID" ] || [ "$APPLE_ID" = "your@email.com" ]; then
    echo_error "APPLE_ID not set in release.config"
    exit 1
fi
if [ -z "$NOTARIZE_PASSWORD" ] || [ "$NOTARIZE_PASSWORD" = "xxxx-xxxx-xxxx-xxxx" ]; then
    echo_error "NOTARIZE_PASSWORD not set in release.config"
    exit 1
fi

# Clean and create build directory
echo_info "Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build Release
echo_info "Building $APP_NAME (Release)..."
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty || xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO

# Copy app to release directory
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo_error "Build failed - app not found at $APP_PATH"
    exit 1
fi
cp -R "$APP_PATH" "$BUILD_DIR/"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo_info "Build complete: $APP_PATH"

# Sign the app
echo_info "Signing with Developer ID..."
codesign --force --deep --sign "$DEVELOPER_ID" \
    --options runtime \
    --timestamp \
    "$APP_PATH"

# Verify signature
echo_info "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# Create ZIP for notarization
echo_info "Creating ZIP for notarization..."
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Notarize
echo_info "Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$NOTARIZE_PASSWORD" \
    --wait

# Staple
echo_info "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Verify notarization
echo_info "Verifying notarization..."
spctl --assess --type exec --verbose "$APP_PATH"

# Create DMG
echo_info "Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# Sign DMG
echo_info "Signing DMG..."
codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"

# Notarize DMG
echo_info "Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$NOTARIZE_PASSWORD" \
    --wait

xcrun stapler staple "$DMG_PATH"

# Cleanup
rm -f "$ZIP_PATH"
rm -rf "$BUILD_DIR/DerivedData"

echo ""
echo_info "Release complete!"
echo_info "App: $APP_PATH"
echo_info "DMG: $DMG_PATH"
echo ""
echo_info "Users can now download and run without Gatekeeper warnings."
