# File: home/home.nix
#
# This module configures core development tools and system services
# like Git and Podman.

{ config, pkgs, lib, ... }:

let
  # Import environment-specific variables. This is necessary to access
  # custom values like user name and email.
  env = import ../env.nix;
in
{
  # --- Package Installation ---
  # Install packages that are configured in this module.
  home.packages = with pkgs; [];


  # --- Git Configuration ---
  # Manages global Git settings.
  programs.git = {
    enable = true;

    # These values are sourced from your env.nix file to keep personal
    # information separate from the configuration logic.
    userName = env.name;
    userEmail = env.email;

    # Add extra global Git settings here.
    extraConfig = {
      # Set the default branch for new repositories to 'main'.
      init.defaultBranch = "main";
    };
  };


  # --- Podman (Container Engine) ---
  # Manages the Podman container engine. By default, Home Manager sets up
  # Podman in a rootless configuration, which is more secure and does not
  # require `sudo` for container management.
  virtualisation.podman = {
    enable = true;

    # Creates a socket that mimics the Docker daemon's socket.
    # This allows tools like `docker-compose` to work with Podman seamlessly.
    dockerCompat = true;

    # Explicitly disable the `alias docker=podman`.
    # This is useful if you want to use the real Docker CLI alongside Podman
    # or simply prefer to type `podman` explicitly.
    docker.enable = false;
  };
}