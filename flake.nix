{
  description = "GnuPG pinentry for Omarchy, in the same overlay dialog as the shell's polkit agent";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
    in
    {
      packages = forAllSystems (pkgs: {
        omapin = pkgs.callPackage ./nix/package.nix { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.omapin;
      });

      overlays.default = final: _prev: {
        omapin = final.callPackage ./nix/package.nix { };
      };

      # programs.omapin, for NixOS and for Home Manager.
      nixosModules = {
        omapin = ./nix/nixos-module.nix;
        default = self.nixosModules.omapin;
      };
      homeModules = {
        omapin = ./nix/home-module.nix;
        default = self.homeModules.omapin;
      };
      # The older name of homeModules.
      homeManagerModules = self.homeModules;

      # Building the package runs the test suite (cargo test).
      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) omapin;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.omapin ];
          packages = with pkgs; [
            clippy
            just
            rust-analyzer
            rustfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
