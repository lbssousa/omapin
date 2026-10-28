# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions
follow [Semantic Versioning](https://semver.org/). Releases from 0.2.1 on
are GPG-signed tags (see the README's "Releases" section). Earlier versions
were never tagged.

## [Unreleased]

### Changed
- The Arch package installs only the `omapin` binary, no longer a copy of
  the shell plugin in `/usr/share/omapin/plugin`: on Omarchy the plugin
  comes from the Omarchy plugin marketplace (`omarchy plugin add
  https://github.com/lbssousa/omapin.git`), as the install message and
  the README now say. Before upgrading, replace a link to the old copy
  with the marketplace's clone. The Nix package still ships the plugin
  for the flake's modules.

## [0.4.0] - 2026-10-27

### Changed
- The shell plugin moved from `plugin/` to the repository root
  (`manifest.json`, `PinentryService.qml`, `PinentryDialog.qml`), so the
  Omarchy plugin marketplace and `omarchy plugin add` can install it. The
  packages install the same files to the same place
  (`share/omapin/plugin`). The manifest gains `license`, `homepage`,
  `repository` and `keywords`, and `docs/dialog.png` becomes `preview.png`.
- `dev/` no longer carries symlinks, which plugins may not have: `just dev`
  and `just test-plugin` build their Quickshell folder in a temporary
  directory. `just link` links the checkout itself and rescans the shell's
  plugins.

### Added
- README sections on installing the plugin alone (`omarchy plugin add`)
  and on removing omapin.
- Flake modules for NixOS (`nixosModules.default`) and Home Manager
  (`homeModules.default`, also as `homeManagerModules`), both as
  `programs.omapin`. They install the package and do the README's
  per-user steps.

## [0.3.1] - 2026-10-20

### Added
- A Nix flake (`flake.nix`, `nix/package.nix`): `packages.<system>.default`,
  `overlays.default`, a dev shell and `nix flake check`. It installs the
  same files as the PKGBUILD (`just nix`).

## [0.3.0] - 2026-10-20

### Changed
- Renamed from pinentry-omarchy to omapin, along with the GitHub
  repository (`lbssousa/omapin`; the old URL redirects). Everything named
  after the project changes with it:
  - binary and package: `/usr/bin/omapin`, `omapin` (the package replaces
    `pinentry-omarchy`), plugin files under `/usr/share/omapin/plugin`;
  - socket: `$XDG_RUNTIME_DIR/omapin.sock`;
  - environment variables: `OMAPIN_SOCKET`, `OMAPIN_FALLBACK`;
  - shell plugin id: `lbssousa.omapin`;
  - Wayland layer namespace of the dialog: `omapin` (was
    `omarchy-pinentry`).

  To upgrade, remove the `~/.config/omarchy/plugins/lbssousa.pinentry`
  link, link and enable `lbssousa.omapin` and point `pinentry-program` in
  `~/.gnupg/gpg-agent.conf` at `/usr/bin/omapin` (see the README's
  "Install" section).

### Security
- The crate now forbids `unsafe` code (`#![forbid(unsafe_code)]`).

### Added
- A contribution guide (`CONTRIBUTING.md`), including the rule that every
  change comes with tests.
- This changelog.

## [0.2.1] - 2026-09-24

### Fixed
- `OK`/`ERR`/`S` response lines could exceed Assuan's 1000-byte line limit
  when the dialog returned a long error message. gpg-agent would then
  reject the line. They're now cut to fit at a character boundary. Found
  by fuzzing.

### Added
- cargo-fuzz targets for the Assuan session, the dialog-reply parser and
  the `D`-line encoder (`fuzz/`, `just fuzz`). They run on every pull
  request that touches the code, and for longer every week.
- A "Releases" section in the README: releases are GPG-signed tags.

### Changed
- The protocol code moved into a library (`src/lib.rs`, `src/session.rs`)
  so the fuzz targets can drive it. The binary's behavior is unchanged.

## 0.2.0 - 2026-09-24

### Security
Found in an internal review; none of these issues had been reported
externally.
- **The PIN lingered in memory that was never wiped.** It was left in a
  `BufReader`'s buffer when reading the dialog's reply, in the standard
  output buffer after the `D` line was written, in serde_json's scratch
  buffer when unescaping, and in temporary hex strings. Every copy now
  lives in a zeroized buffer, and responses are written to gpg-agent
  unbuffered.
- **Assuan injection:** an error message from the dialog was echoed into an
  `ERR` line without escaping, so a message containing newlines could
  inject `D`/`OK` lines into what gpg-agent read. Response lines are now
  free of control characters.
- **Display spoofing:** texts from gpg-agent (for example a key's user ID
  in `SETDESC`) could use control characters or bidirectional overrides to
  disguise what the dialog showed. They're now stripped.
- **Unbounded input:** `SETTIMEOUT` could overflow (in the binary and in the
  plugin's timer), and gpg-agent lines had no length limit. Timeouts are now
  capped at one day, and lines at Assuan's 1000 bytes.
- The fallback pinentries are now run by absolute path.

### Changed
- **Protocol v2** between the binary and the plugin: the PIN travels
  percent-encoded. The plugin refuses any other protocol version, so
  mismatched halves fail closed instead of sending the card a misread PIN.
  After upgrading, restart omarchy-shell.

### Added
- `SECURITY.md` (threat model, private vulnerability reporting).
- Much broader unit and integration tests, and protocol tests against the
  real QML plugin (`just test-plugin`).
- GitHub security tooling: CI, CodeQL, cargo-deny, OpenSSF Scorecard,
  Dependabot.

## 0.1.1 - 2026-09-24

### Fixed
- omarchy-shell logged a `PeerClosedError` warning for every prompt. The
  startup availability check now reuses its connection for the first
  prompt, and the plugin closes each connection itself after answering.

## 0.1.0 - 2026-09-24

### Added
- First release. The Rust pinentry speaks Assuan to gpg-agent, and the
  omarchy-shell plugin draws the prompt in the polkit agent's overlay
  dialog: `GETPIN` (with `SETREPEAT`), `CONFIRM`, `MESSAGE`. Without the
  shell it falls back to pinentry-gnome3 or pinentry-curses.
- Arch package (`packaging/PKGBUILD`).

[Unreleased]: https://github.com/lbssousa/omapin/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/lbssousa/omapin/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/lbssousa/omapin/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/lbssousa/omapin/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/lbssousa/omapin/releases/tag/v0.2.1
