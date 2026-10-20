# Builds the same files as packaging/PKGBUILD: the binary in bin/ and the
# shell plugin in share/omapin/plugin. The version comes from Cargo.toml.
{
  lib,
  rustPlatform,
  pinentry-gnome3,
  pinentry-curses,
}:
let
  cargoToml = (lib.importTOML ../Cargo.toml).package;
in
rustPlatform.buildRustPackage {
  pname = cargoToml.name;
  inherit (cargoToml) version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../src
      ../tests
      ../plugin
    ];
  };

  cargoLock.lockFile = ../Cargo.lock;

  # The fallback pinentries are looked up at /usr/bin, which Nix doesn't
  # have.
  postPatch = ''
    substituteInPlace src/fallback.rs \
      --replace-fail /usr/bin/pinentry-gnome3 ${lib.getExe' pinentry-gnome3 "pinentry-gnome3"} \
      --replace-fail /usr/bin/pinentry-curses ${lib.getExe' pinentry-curses "pinentry-curses"}
  '';

  postInstall = ''
    install -Dm644 -t $out/share/omapin/plugin plugin/manifest.json plugin/*.qml
  '';

  meta = {
    description = cargoToml.description;
    homepage = "https://github.com/lbssousa/omapin";
    license = lib.licenses.mit;
    mainProgram = "omapin";
    platforms = lib.platforms.linux;
  };
}
