#!/bin/bash
# ---------------------------------------------------------
# Android CLI Development Environment Setup Script
# ---------------------------------------------------------
set -e # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if config.env exists
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

TARGET_USER="${DEV_USER:-$USER}"
TARGET_HOME=$(eval echo "~${TARGET_USER}")
ANDROID_SDK_DIR="${TARGET_HOME}/Android/Sdk"

echo "========================================================================"
echo "Setting up Android CLI Toolchain for user: ${TARGET_USER}"
echo "Android SDK Target Directory: ${ANDROID_SDK_DIR}"
echo "========================================================================"

# Check and install system dependencies if needed
if ! command -v java &> /dev/null || ! command -v adb &> /dev/null; then
    echo "--- Installing OpenJDK 17, ADB, and compression utilities ---"
    sudo apt update
    sudo apt install -y openjdk-17-jdk adb unzip curl wget
else
    echo "--- System dependencies (Java/ADB) already installed ---"
fi

echo "--- Setting up Android Command-line Tools & SDK Structure ---"
mkdir -p "${ANDROID_SDK_DIR}/cmdline-tools"

if [ ! -d "${ANDROID_SDK_DIR}/cmdline-tools/latest" ]; then
    echo "Downloading latest Android Command-line Tools..."
    TMP_ZIP="/tmp/cmdline-tools.zip"
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o "${TMP_ZIP}"
    
    echo "Extracting Command-line Tools..."
    rm -rf /tmp/cmdline-tools-extracted
    mkdir -p /tmp/cmdline-tools-extracted
    unzip -q "${TMP_ZIP}" -d /tmp/cmdline-tools-extracted
    
    mkdir -p "${ANDROID_SDK_DIR}/cmdline-tools/latest"
    mv /tmp/cmdline-tools-extracted/cmdline-tools/* "${ANDROID_SDK_DIR}/cmdline-tools/latest/"
    rm -rf "${TMP_ZIP}" /tmp/cmdline-tools-extracted
    echo "Command-line Tools installed successfully."
fi

# Define environment variables for script execution
export ANDROID_HOME="${ANDROID_SDK_DIR}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_DIR}"
export PATH="${PATH}:${ANDROID_SDK_DIR}/cmdline-tools/latest/bin:${ANDROID_SDK_DIR}/platform-tools:${ANDROID_SDK_DIR}/build-tools/35.0.0"

echo "--- Accepting Android SDK Licenses & Installing Required Packages ---"
SDKMANAGER="${ANDROID_SDK_DIR}/cmdline-tools/latest/bin/sdkmanager"
chmod +x "${SDKMANAGER}"

yes | "${SDKMANAGER}" --sdk_root="${ANDROID_SDK_DIR}" --licenses || true
"${SDKMANAGER}" --sdk_root="${ANDROID_SDK_DIR}" "platforms;android-35" "build-tools;35.0.0" "platform-tools"

echo "--- Configuring Environment Variables in ~/.bashrc ---"
BASHRC="${TARGET_HOME}/.bashrc"
if ! grep -q "ANDROID_HOME" "${BASHRC}"; then
    echo "" >> "${BASHRC}"
    echo "# Android SDK CLI Environment" >> "${BASHRC}"
    echo "export ANDROID_HOME=${ANDROID_SDK_DIR}" >> "${BASHRC}"
    echo "export ANDROID_SDK_ROOT=${ANDROID_SDK_DIR}" >> "${BASHRC}"
    echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/build-tools/35.0.0" >> "${BASHRC}"
    echo "Added ANDROID_HOME and PATH exports to ${BASHRC}"
fi

echo "--- Updating mavlink-hud local.properties ---"
APP_LOCAL_PROPS="${TARGET_HOME}/projects/led-drone-microcontrollers/mavlink-hud/android-app/local.properties"
if [ -f "${APP_LOCAL_PROPS}" ]; then
    echo "sdk.dir=${ANDROID_SDK_DIR}" > "${APP_LOCAL_PROPS}"
    echo "Updated ${APP_LOCAL_PROPS} to point to ${ANDROID_SDK_DIR}"
fi

# Set proper ownership
chown -R "${TARGET_USER}:${TARGET_USER}" "${ANDROID_SDK_DIR}" 2>/dev/null || true

echo "========================================================================"
echo "🎉 Android CLI Environment Setup Complete!"
echo "SDK Location: ${ANDROID_SDK_DIR}"
echo "========================================================================"
