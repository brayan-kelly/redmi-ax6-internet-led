#!/bin/bash
# create-internet-led-tarball.sh
# Creates a tarball containing:
#   - files/ (the installed file hierarchy)
#   - install.sh (installation script)
#   - uninstall.sh (removal script)

set -e

TARBALL_NAME="luci-app-internet-led.tar.gz"
SOURCE_DIR="files"
WORK_DIR="internet-led-pkg"

# Check that the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Directory '$SOURCE_DIR' not found." >&2
    exit 1
fi

# Create a clean working directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Copy the existing files/ tree into the working directory
cp -a "$SOURCE_DIR" "$WORK_DIR/"

# Ensure all scripts are executable
echo "Setting executable permissions on scripts..."
chmod +x "$WORK_DIR"/files/usr/bin/internet-led.sh 2>/dev/null || true
chmod +x "$WORK_DIR"/files/usr/libexec/rpcd/internet-led-lists 2>/dev/null || true
chmod +x "$WORK_DIR"/files/etc/init.d/internet-led 2>/dev/null || true
chmod +x "$WORK_DIR"/files/etc/uci-defaults/99_internet-led 2>/dev/null || true

# Create install.sh
cat > "$WORK_DIR"/install.sh << 'EOF'
#!/bin/sh
# Install script for Internet LED LuCI app

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must be run as root." >&2
    exit 1
fi

echo "Installing Internet LED files..."
cp -a files/* /

# Run uci-defaults script if it exists
if [ -x /etc/uci-defaults/99_internet-led ]; then
    echo "Running uci-defaults..."
    /etc/uci-defaults/99_internet-led
fi

# Restart services
echo "Restarting services..."
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
/etc/init.d/internet-led start

echo "Internet LED installed. You can now access it at LuCI → Status → Internet LED."
EOF

chmod +x "$WORK_DIR"/install.sh

# Create uninstall.sh
cat > "$WORK_DIR"/uninstall.sh << 'EOF'
#!/bin/sh
# uninstall.sh – Remove Internet LED from OpenWrt

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

echo "Stopping internet-led service..."
/etc/init.d/internet-led stop 2>/dev/null || true

echo "Disabling internet-led service..."
/etc/init.d/internet-led disable 2>/dev/null || true

echo "Removing configuration and binaries..."
rm -f /etc/config/internet-led \
      /etc/init.d/internet-led \
      /usr/bin/internet-led.sh \
      /usr/libexec/rpcd/internet-led-lists \
      /usr/share/rpcd/acl.d/luci-app-internet-led.json \
      /usr/share/luci/menu.d/luci-app-internet-led.json \
      /www/luci-static/resources/view/internet-led/*

# Remove the view directory if empty
rmdir /www/luci-static/resources/view/internet-led 2>/dev/null || true

echo "Restarting rpcd and uhttpd..."
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

echo "Internet LED removed successfully."
EOF

chmod +x "$WORK_DIR"/uninstall.sh

# Create the tarball from the working directory
echo "Creating tarball $TARBALL_NAME..."
tar -czf "$TARBALL_NAME" -C "$WORK_DIR" .

# Clean up
rm -rf "$WORK_DIR"

echo "Done. To install on your router:"
echo "  scp $TARBALL_NAME root@router:/tmp/"
echo "  ssh root@router"
echo "  cd / && tar -xzf /tmp/$TARBALL_NAME && ./install.sh"
echo "To uninstall later, run: ./uninstall.sh"