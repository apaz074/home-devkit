# File: lib/default.nix
#
# This is a "module assembler". It's a function that dynamically builds the
# final list of modules to be loaded by Home Manager.

# It receives `lib` from nixpkgs and `env` from flake.nix as arguments.
{ lib, env }:

let
  # Path to the user's local, untracked modules directory.
  userModulesPath = ./../modules;

  # This expression scans the user's local directory and returns a list
  # of paths to any .nix files found inside.
  userModules =
    if builtins.pathExists userModulesPath then
      let
        files = builtins.readDir userModulesPath;
      in
        map (file: userModulesPath + "/${file}")
          (lib.filter
            (file: (builtins.getAttr file files) == "regular" && lib.hasSuffix ".nix" file)
            (lib.attrNames files))
    else
      # If the directory doesn't exist, return an empty list.
      [];
in
# The final output of this file is the complete list of modules.
[
  # 1. Always include the base configuration.
  ./../home/home.nix
]
# 2. Append the list of user-specific modules found (if any).
++ userModules
# 3. Append the final inline module with user data.
++ [
  {
    home.username = env.username;
    home.homeDirectory = env.homeDirectory;
    home.stateVersion = "25.05";
  }
]