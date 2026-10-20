# NixOS module (nixosModules.default): installs omapin system-wide, makes
# gpg-agent use it and links the shell plugin for every user. Enabling the
# plugin in the shell is left to each user's session
# (`omarchy-shell shell enablePlugin lbssousa.omapin '{}'`), or to the Home
# Manager module.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.omapin;
  pluginId = "lbssousa.omapin";
in
{
  options.programs.omapin = {
    enable = lib.mkEnableOption "omapin, a GnuPG pinentry in the Omarchy shell's polkit-style dialog";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "omapin.packages.\${system}.default";
      description = "The omapin package.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Takes effect with programs.gnupg.agent.enable.
    programs.gnupg.agent.pinentryPackage = lib.mkDefault cfg.package;

    # Third-party shell plugins are only discovered in
    # ~/.config/omarchy/plugins/.
    systemd.user.tmpfiles.rules = [
      "L+ %h/.config/omarchy/plugins/${pluginId} - - - - ${cfg.package}/share/omapin/plugin"
    ];
  };
}
