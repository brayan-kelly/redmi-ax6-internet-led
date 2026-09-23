#!/bin/sh

set -eu

FEED_BASE="https://brayan-kelly.github.io/redmi-ax6-internet-led/feed"
KEY_SHA256="e5f197a71d2255e5e06e4ad08ed522822cd32b52f012b7e33e9751735de495a5"
PACKAGE_NAME="luci-app-internet-led"
KEY_PATH="/etc/apk/keys/internet-led.pub"
REPOSITORY_PATH="/etc/apk/repositories.d/internet-led.list"

fail() {
	echo "Error: $*" >&2
	exit 1
}

[ "$(id -u)" -eq 0 ] || fail "run this installer as root"
[ -r /etc/apk/arch ] || fail "cannot read /etc/apk/arch"

APK_ARCH=$(cat /etc/apk/arch)
case "$APK_ARCH" in
	aarch64_cortex-a53) ;;
	*) fail "unsupported architecture: $APK_ARCH (available feed: aarch64_cortex-a53)" ;;
esac

for utility in apk wget sha256sum; do
	command -v "$utility" >/dev/null 2>&1 || fail "required command not found: $utility"
done

TMP_DIR=$(mktemp -d /tmp/internet-led-install.XXXXXX) || fail "could not create temporary directory"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading the Internet LED feed key..."
wget -q -O "$TMP_DIR/internet-led.pub" "$FEED_BASE/internet-led.pub" || fail "could not download the feed key"
printf '%s  %s\n' "$KEY_SHA256" "$TMP_DIR/internet-led.pub" | sha256sum -c - || fail "feed key fingerprint does not match"

mkdir -p /etc/apk/keys /etc/apk/repositories.d
cp "$TMP_DIR/internet-led.pub" "$KEY_PATH"
chmod 0644 "$KEY_PATH"
printf '%s\n' "$FEED_BASE/$APK_ARCH/packages.adb" > "$REPOSITORY_PATH"

echo "Refreshing APK indexes..."
apk update
echo "Installing $PACKAGE_NAME from the signed feed..."
apk add "$PACKAGE_NAME"
echo "Installed $PACKAGE_NAME successfully."
