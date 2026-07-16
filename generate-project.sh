#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

XCODEGEN_CMD="xcodegen"
LOCAL_XCODEGEN_DIR="$PROJECT_DIR/.xcodegen"

# Check if xcodegen is already installed
if command -v xcodegen >/dev/null 2>&1; then
    echo "✅ xcodegen is already installed globally."
else
    echo "⚠️ xcodegen is not installed globally. Attempting to install or configure a local copy..."

    # Check if brew is installed
    if command -v brew >/dev/null 2>&1; then
        echo "🍺 Homebrew detected. Installing xcodegen via Homebrew..."
        brew install xcodegen
    else
        echo "🔍 Homebrew not found. Downloading pre-compiled XcodeGen binary from GitHub..."
        
        # Download and extract the latest stable release to a local directory
        VERSION="2.45.4"
        ZIP_URL="https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"
        
        mkdir -p "$LOCAL_XCODEGEN_DIR"
        echo "Downloading XcodeGen v${VERSION}..."
        curl -L "$ZIP_URL" -o "$LOCAL_XCODEGEN_DIR/xcodegen.zip"
        
        echo "Extracting XcodeGen..."
        unzip -q -o "$LOCAL_XCODEGEN_DIR/xcodegen.zip" -d "$LOCAL_XCODEGEN_DIR"
        rm "$LOCAL_XCODEGEN_DIR/xcodegen.zip"
        
        # Move nested folder contents up if necessary
        if [ -d "$LOCAL_XCODEGEN_DIR/xcodegen" ]; then
            mv "$LOCAL_XCODEGEN_DIR/xcodegen/"* "$LOCAL_XCODEGEN_DIR/"
            mv "$LOCAL_XCODEGEN_DIR/xcodegen/".* "$LOCAL_XCODEGEN_DIR/" 2>/dev/null || true
            rmdir "$LOCAL_XCODEGEN_DIR/xcodegen"
        fi
        
        # Make the binary executable
        chmod +x "$LOCAL_XCODEGEN_DIR/bin/xcodegen"
        XCODEGEN_CMD="$LOCAL_XCODEGEN_DIR/bin/xcodegen"
        
        echo "✅ XcodeGen installed locally at $LOCAL_XCODEGEN_DIR/bin/xcodegen."
    fi
fi

# Run xcodegen to generate the project
echo "⚙️ Generating Xcode project..."
$XCODEGEN_CMD generate
