#!/usr/bin/env bash

# Smart installer for NetFRIX
# Supports: macOS, Ubuntu/Debian, Fedora, Arch Linux

set -euo pipefail

# Constants
PROGRAM_NAME="NetFRIX"
VERSION="0.4"
GITHUB_URL="https://raw.githubusercontent.com/your-repo/netfrix/main"
INSTALL_DIR="/usr/local/bin"
DATA_DIR="/usr/local/share/netfrix"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Detect OS and package manager
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    if ! command -v brew >/dev/null; then
      error "Homebrew is required for macOS installation"
      info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    PKG_MANAGER="brew"
    PKG_INSTALL="brew install"
    PKG_UPDATE="brew update"
  else
    # Linux detection
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      OS="linux"
      case "$ID" in
      debian | ubuntu | pop | mint)
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        ;;
      fedora | rhel | centos)
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update"
        ;;
      arch | manjaro)
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        ;;
      *)
        error "Unsupported Linux distribution: $ID"
        exit 1
        ;;
      esac
    else
      error "Could not detect Linux distribution"
      exit 1
    fi
  fi
}

# Check if running as root/sudo
check_privileges() {
  if [[ "$OS" == "linux" && $EUID -ne 0 ]]; then
    error "This script must be run as root on Linux"
    info "Please run with: sudo $0"
    exit 1
  fi
}

# Install dependencies based on OS
install_dependencies() {
  info "Installing dependencies for $OS with $PKG_MANAGER..."

  eval "$PKG_UPDATE"

  case "$PKG_MANAGER" in
  brew)
    brew install ffmpeg openssh
    ;;
  apt)
    $PKG_INSTALL ffmpeg openssh-client
    ;;
  dnf)
    $PKG_INSTALL ffmpeg openssh
    ;;
  pacman)
    $PKG_INSTALL ffmpeg openssh
    ;;
  esac

  # Check if installation was successful
  if ! command -v ffmpeg >/dev/null || ! command -v ssh >/dev/null; then
    error "Failed to install required dependencies"
    exit 1
  fi
}

# Configure SSH key if needed
setup_ssh() {
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    info "Generating SSH key..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  fi

  info "Would you like to copy your SSH key to the video server? (y/n)"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    read -p "Enter server username: " server_user
    read -p "Enter server IP: " server_ip

    if ! ssh-copy-id "${server_user}@${server_ip}"; then
      warning "Failed to copy SSH key. You may need to do this manually."
    fi
  fi
}

# Create necessary directories and copy files
setup_program() {
  info "Setting up NetFRIX..."

  # Create directories
  mkdir -p "$INSTALL_DIR"
  mkdir -p "$DATA_DIR"

  # Download and install main program
  curl -s "$GITHUB_URL/netfrix.sh" >"$INSTALL_DIR/netfrix"
  chmod +x "$INSTALL_DIR/netfrix"

  # Create desktop entry for Linux
  if [[ "$OS" == "linux" ]]; then
    cat >/usr/share/applications/netfrix.desktop <<EOF
[Desktop Entry]
Name=NetFRIX
Comment=Video Streaming Interface
Exec=$INSTALL_DIR/netfrix
Icon=video-player
Terminal=true
Type=Application
Categories=AudioVideo;Video;Player;
EOF
  fi

  # Create configuration file
  cat >"$DATA_DIR/config.conf" <<EOF
# NetFRIX Configuration
SSH_USER="$server_user"
SSH_HOST="$server_ip"
REMOTE_VIDEO_PATH="/mnt/videos"
EOF
}

# Main installation function
main() {
  echo "Starting $PROGRAM_NAME v$VERSION installation..."

  detect_os
  check_privileges
  install_dependencies
  setup_ssh
  setup_program

  success "Installation completed successfully!"
  info "You can now run NetFRIX by typing 'netfrix' in terminal"

  if [[ "$OS" == "linux" ]]; then
    info "Or launch it from your application menu"
  fi
}

# Run uninstaller if requested
uninstall() {
  info "Uninstalling NetFRIX..."

  rm -f "$INSTALL_DIR/netfrix"
  rm -rf "$DATA_DIR"

  if [[ "$OS" == "linux" ]]; then
    rm -f /usr/share/applications/netfrix.desktop
  fi

  success "NetFRIX has been uninstalled"
}

# Parse command line arguments
case "${1:-install}" in
install)
  main
  ;;
uninstall)
  uninstall
  ;;
--help | -h)
  echo "Usage: $0 [install|uninstall]"
  exit 0
  ;;
*)
  error "Unknown option: $1"
  echo "Usage: $0 [install|uninstall]"
  exit 1
  ;;
esac
