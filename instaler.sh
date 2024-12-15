#!/usr/bin/env bash

# installer.sh
# Installation script for NetFRIX

set -euo pipefail

# Configuration
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/usr/local/share/netfrix"
PROGRAM_NAME="netfrix"
PROGRAM_SOURCE="netfrix.sh" # Nome do seu script principal

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root${NC}"
  exit 1
fi

echo "Installing NetFRIX..."

# Create necessary directories
mkdir -p "${DATA_DIR}"
mkdir -p "${INSTALL_DIR}"

# Copy main program
cp "${PROGRAM_SOURCE}" "${INSTALL_DIR}/${PROGRAM_NAME}"
chmod +x "${INSTALL_DIR}/${PROGRAM_NAME}"

# Create initial database directory
mkdir -p "${DATA_DIR}"

# Set permissions
chown -R root:root "${DATA_DIR}"
chmod 755 "${DATA_DIR}"

# Create desktop entry
cat >/usr/share/applications/netfrix.desktop <<EOF
[Desktop Entry]
Name=NetFRIX
Comment=Video Streaming Interface
Exec=${INSTALL_DIR}/${PROGRAM_NAME}
Icon=video-player
Terminal=true
Type=Application
Categories=AudioVideo;Video;Player;
EOF

echo -e "${GREEN}Installation completed!${NC}"
echo "You can now run NetFRIX by typing 'netfrix' in terminal"
echo "or launching it from your application menu."
