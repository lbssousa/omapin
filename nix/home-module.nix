# Home Manager module (homeModules.default): what the README's "Per user"
# steps do, for one user.
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

    enablePlugin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable the ${pluginId} plugin in the running omarchy-shell
        on activation (`omarchy-shell shell enablePlugin`). The shell records
        it in ~/.config/omarchy/shell.json. Without a running shell this only
        prints a warning.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Third-party shell plugins are only discovered here.
    xdg.configFile."omarchy/plugins/${pluginId}".source = "${cfg.package}/share/omapin/plugin";

    # Takes effect with services.gpg-agent.enable. Without it, point
    # pinentry-program in ~/.gnupg/gpg-agent.conf at
    # ~/.nix-profile/bin/omapin yourself.
    services.gpg-agent.pinentry.package = lib.mkDefault cfg.package;

    home.activation.omapinEnablePlugin = lib.mkIf cfg.enablePlugin (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        omarchy_shell=$(PATH="$PATH:/usr/bin" command -v omarchy-shell || true)
        if [[ -n $omarchy_shell && ! -v DRY_RUN ]]; then
          if [[ $("$omarchy_shell" shell enablePlugin ${pluginId} '{}' 2>/dev/null) != ok ]]; then
            warnEcho "Couldn't enable the ${pluginId} shell plugin (is omarchy-shell running?)."
            warnEcho "Run: omarchy-shell shell enablePlugin ${pluginId} '{}'"
          fi
        fi
      ''
    );
  };
}
