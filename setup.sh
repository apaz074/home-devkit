#!/usr/bin/env bash

# Exit immediately if a command fails.
set -e

# --- Color Variables ---
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m' # No Color

# --- Global Variables ---
REPO_URL="https://github.com/apaz074/home-devkit.git"
CLONE_PATH="" # Will be set in the clone_repo function

# --- Helper Functions ---
info() {
    echo -e "${COLOR_BLUE}INFO: $1${COLOR_NC}"
}

success() {
    echo -e "${COLOR_GREEN}SUCCESS: $1${COLOR_NC}"
}

warning() {
    echo -e "${COLOR_YELLOW}WARNING: $1${COLOR_NC}"
}

error() {
    echo -e "${COLOR_RED}ERROR: $1${COLOR_NC}" >&2
    exit 1
}

# --- Main Functions ---

install_nix() {
    info "Checking for Nix installation..."
    if command -v nix &> /dev/null; then
        success "Nix is already installed."
    else
        info "Nix not found. Starting installation (single-user mode)..."
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
        success "Nix has been installed."
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
        warning "Nix has been loaded into the current session."
    fi

    info "Enabling Flakes..."
    NIX_CONF_DIR="$HOME/.config/nix"
    NIX_CONF_PATH="$NIX_CONF_DIR/nix.conf"
    mkdir -p "$NIX_CONF_DIR"
    if [ -f "$NIX_CONF_PATH" ] && grep -q "experimental-features.*nix-command.*flakes" "$NIX_CONF_PATH"; then
        success "Flakes appear to be already enabled."
    else
        info "Adding Flakes configuration to $NIX_CONF_PATH..."
        echo "experimental-features = nix-command flakes" >> "$NIX_CONF_PATH"
        success "Flakes enabled."
    fi
}

clone_repo() {
    info "The configuration repository will be cloned into your home directory ($HOME)."
    read -p "Enter the destination folder name [home-devkit]: " DEST_DIR_NAME
    DEST_DIR_NAME=${DEST_DIR_NAME:-home-devkit}
    CLONE_PATH="$HOME/$DEST_DIR_NAME"

    if [ -d "$CLONE_PATH" ] && [ -d "$CLONE_PATH/.git" ]; then
        warning "Directory '$CLONE_PATH' already exists and appears to be a repository. Skipping clone."
    else
        mkdir -p "$CLONE_PATH"
        info "Cloning repository into '$CLONE_PATH'..."
        nix-shell -p git --run "git clone --depth 1 '$REPO_URL' '$CLONE_PATH'"
        success "Repository cloned successfully."
    fi
}

configure_env_file() {
    local EXAMPLE_FILE="$CLONE_PATH/env.nix.example"
    local ENV_FILE="$CLONE_PATH/env.nix"

    info "Configuring environment file..."
    if [ ! -f "$EXAMPLE_FILE" ]; then
        error "Template file '$EXAMPLE_FILE' not found in the repository. Cannot proceed."
    fi

    info "Creating 'env.nix' from template..."
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    success "'env.nix' created."

    # 1. Ask for name and email
    read -p "Enter your full name (for Git): " git_name
    read -p "Enter your email (for Git): " git_email

    # 2. Get username and home automatically
    local username="$USER"
    local home_dir="$HOME"

    # 3. Ask for the system architecture
    info "Please select your system architecture (default is x86_64-linux):"
    local systems=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" "Other")
    select system_choice in "${systems[@]}"; do
        case $system_choice in
            "Other")
                read -p "Please enter your system architecture (e.g., riscv64-linux): " system_arch
                break
                ;;
            *)
                system_arch=$system_choice
                break
                ;;
        esac
    done

    info "Updating '$ENV_FILE' with your information..."
    # Use sed to replace the values in the newly created env.nix
    sed -i "s|name = \".*\"|name = \"${git_name}\"|" "$ENV_FILE"
    sed -i "s|email = \".*\"|email = \"${git_email}\"|" "$ENV_FILE"
    sed -i "s|username = \".*\"|username = \"${username}\"|" "$ENV_FILE"
    sed -i "s|homeDirectory = \".*\"|homeDirectory = \"${home_dir}\"|" "$ENV_FILE"

    # Only modify the architecture if it's not the default
    if [ "$system_arch" != "x86_64-linux" ]; then
        info "Selected architecture is not the default. Updating env.nix..."
        sed -i "s|system = \".*\"|system = \"${system_arch}\"|" "$ENV_FILE"
    else
        info "Keeping default architecture (x86_64-linux)."
    fi

    success "'env.nix' has been configured."
    info "Final content of env.nix:"
    cat "$ENV_FILE"
}

apply_configuration() {
    info "Applying Home Manager configuration. This may take several minutes the first time..."
    warning "Nix will download and build all packages defined in the configuration."
    nix run home-manager/stable -- switch --flake "$CLONE_PATH"
    success "Configuration complete! Your new environment is ready."
    warning "Please open a new terminal to see all the changes."
}

# --- Main Script Flow ---
main() {
    info "--- Starting development environment setup ---"
    
    install_nix
    clone_repo
    configure_env_file
    apply_configuration

    echo -e "\n${COLOR_GREEN}All set! Your declarative development environment has been configured successfully.${COLOR_NC}"
    echo -e "For future changes, edit the files in '$CLONE_PATH' and run 'home-manager switch --flake $CLONE_PATH'."
}

# Execute the main function
main