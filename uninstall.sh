#!/bin/bash
#
# OpenClaw (Clawbot) Docker Uninstaller
# Removes OpenClaw installation from your system
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/openclaw-docker/main/uninstall.sh)
#
# Or with options:
#   bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/openclaw-docker/main/uninstall.sh) --keep-data
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Config
INSTALL_DIR="${OPENCLAW_INSTALL_DIR:-$HOME/openclaw}"
IMAGE="ghcr.io/phioranex/openclaw-docker:latest"

# Flags
KEEP_DATA=false
KEEP_IMAGE=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --keep-image)
            KEEP_IMAGE=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "OpenClaw (Clawbot) Docker Uninstaller"
            echo ""
            echo "Usage: uninstall.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR   Installation directory (default: ~/openclaw)"
            echo "  --keep-data         Keep configuration and workspace data"
            echo "  --keep-image        Keep Docker image"
            echo "  --force, -f         Skip confirmation prompts"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Functions
print_banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║    ____                    _____ _                           ║"
    echo "║   / __ \\\\                  / ____| |                          ║"
    echo "║  | |  | |_ __   ___ _ __ | |    | | __ ___      __           ║"
    echo "║  | |  | | '_ \\\\ / _ \\\\ '_ \\\\| |    | |/ _\\\` \\\\ \\\\ /\\\\ / /           ║"
    echo "║  | |__| | |_) |  __/ | | | |____| | (_| |\\\\ V  V /            ║"
    echo "║   \\\\____/| .__/ \\\\___|_| |_|\\\\_____|_|\\\\__,_| \\\\_/\\\\_/             ║"
    echo "║         | |                                                  ║"
    echo "║         |_|                                                  ║"
    echo "║                                                              ║"
    echo "║            Docker Uninstaller by Phioranex                   ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Get user's home directory, handling sudo correctly
get_user_home() {
    if [ -n "$SUDO_USER" ]; then
        # Running with sudo - use the actual user's home
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -z "$user_home" ]; then
            # Fallback to eval if getent fails
            user_home=$(eval echo ~"$SUDO_USER")
        fi
        echo "$user_home"
    else
        # Running normally
        echo "$HOME"
    fi
}

log_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    while true; do
        read -p "$(echo -e "${YELLOW}$prompt${NC}")" -r response
        response=${response:-$default}
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Main script
print_banner

echo -e "${YELLOW}This will uninstall OpenClaw from your system.${NC}"
echo ""

# Stop and remove containers
log_step "Stopping and removing containers..."

CONTAINERS_REMOVED=false
if docker ps -a --format '{{.Names}}' | grep -q "openclaw-gateway"; then
    docker stop openclaw-gateway 2>/dev/null || true
    docker rm openclaw-gateway 2>/dev/null || true
    log_success "Removed openclaw-gateway container"
    CONTAINERS_REMOVED=true
fi

if docker ps -a --format '{{.Names}}' | grep -q "openclaw-socat"; then
    docker stop openclaw-socat 2>/dev/null || true
    docker rm openclaw-socat 2>/dev/null || true
    log_success "Removed openclaw-socat container"
    CONTAINERS_REMOVED=true
fi

if docker ps -a --format '{{.Names}}' | grep -q "openclaw-cli"; then
    docker rm openclaw-cli 2>/dev/null || true
    log_success "Removed openclaw-cli container"
    CONTAINERS_REMOVED=true
fi

if [ "$CONTAINERS_REMOVED" = false ]; then
    log_warning "No OpenClaw containers found"
fi

# Remove data directories
USER_HOME=$(get_user_home)
OPENCLAW_DIR="$USER_HOME/.openclaw"

if [ "$KEEP_DATA" = false ] && [ -d "$OPENCLAW_DIR" ]; then
    log_step "Data directories found at $OPENCLAW_DIR"
    
    if confirm "Remove configuration and workspace data? (This cannot be undone)"; then
        rm -rf "$OPENCLAW_DIR"
        log_success "Removed data directory: $OPENCLAW_DIR"
    else
        log_warning "Keeping data directory: $OPENCLAW_DIR"
    fi
elif [ "$KEEP_DATA" = true ] && [ -d "$OPENCLAW_DIR" ]; then
    log_warning "Keeping data directory: $OPENCLAW_DIR"
elif [ ! -d "$OPENCLAW_DIR" ]; then
    log_warning "No data directory found at $OPENCLAW_DIR"
fi

# Remove Docker image
if [ "$KEEP_IMAGE" = false ]; then
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$IMAGE"; then
        log_step "Docker image found: $IMAGE"
        
        if confirm "Remove Docker image? (You can re-download it later)"; then
            docker rmi "$IMAGE" 2>/dev/null || log_warning "Could not remove image (may be in use)"
            log_success "Removed Docker image"
        else
            log_warning "Keeping Docker image: $IMAGE"
        fi
    else
        log_warning "No Docker image found: $IMAGE"
    fi
else
    log_warning "Keeping Docker image: $IMAGE"
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    log_step "Installation directory found at $INSTALL_DIR"
    
    if confirm "Remove installation directory?"; then
        rm -rf "$INSTALL_DIR"
        log_success "Removed installation directory: $INSTALL_DIR"
    else
        log_warning "Keeping installation directory: $INSTALL_DIR"
    fi
else
    log_warning "No installation directory found at $INSTALL_DIR"
fi

# Success message
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║         OpenClaw has been uninstalled successfully! 👋        ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

if [ "$KEEP_DATA" = true ] || [ -d "$OPENCLAW_DIR" ]; then
    echo -e "\n${BOLD}Data preserved:${NC}"
    echo -e "  ${CYAN}Config:${NC}         $OPENCLAW_DIR"
    echo -e "  ${CYAN}Workspace:${NC}      $OPENCLAW_DIR/workspace"
fi

echo -e "\n${BOLD}To reinstall OpenClaw:${NC}"
echo -e "  ${CYAN}bash <(curl -fsSL https://raw.githubusercontent.com/phioranex/openclaw-docker/main/install.sh)${NC}"

echo -e "\n${YELLOW}Thank you for using OpenClaw! 🦞${NC}\n"
