# omapin

[![ci](https://github.com/lbssousa/omapin/actions/workflows/ci.yml/badge.svg)](https://github.com/lbssousa/omapin/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/lbssousa/omapin/badge)](https://scorecard.dev/viewer/?uri=github.com/lbssousa/omapin)

A GnuPG [pinentry](https://www.gnupg.org/related_software/pinentry/) for
[Omarchy](https://omarchy.org/) that asks for PINs and passphrases in the
same overlay dialog as the shell's polkit agent: same layer, scrim, card,
fonts, `[polkit]` theme colours and failure shake, following theme changes
live.

omapin was called **pinentry-omarchy** until 0.2.1. The binary, package,
socket, environment variables (`PINENTRY_OMARCHY_*` → `OMAPIN_*`) and
shell plugin (`lbssousa.pinentry` → `lbssousa.omapin`) were renamed with
it; see [CHANGELOG.md](CHANGELOG.md) for upgrading.

![A GnuPG PIN prompt drawn as a full-screen overlay dialog, in the Tokyo Night theme](preview.png)

## How it works

```
gpg-agent ──Assuan (stdin/stdout)──▶ omapin (Rust)
                                        │ one NDJSON line each way
                                        ▼
            $XDG_RUNTIME_DIR/omapin.sock
                                        │
                  plugin lbssousa.omapin (service) inside omarchy-shell
                                        │
                                  overlay dialog
```

- **`omapin`** (`src/`) speaks the pinentry Assuan protocol to
  gpg-agent: `GETPIN` (with `SETREPEAT`), `CONFIRM` (incl.
  `--one-button`), `MESSAGE`, the `SET*` texts and labels, `SETTIMEOUT`,
  `GETINFO`. For each prompt it sends the request over a connection to
  the plugin's socket (checking that the peer runs as the same user) and
  relays the answer. The connection opened at startup to check that the
  plugin is up carries the first prompt; the plugin closes each connection
  after answering.
- **The plugin** (`manifest.json` and the QML files at the repository
  root) is a third-party Omarchy shell plugin of kind
  `service`. It reuses the shell's own `qs.Commons` (`Color`, `Style`,
  `Border`) and `qs.Ui` (`BorderSurface`, `Button`) instead of copying
  styles. One request is served at a time; a second one gets `busy`. A
  client that disconnects (gpg-agent killing the pinentry, for example)
  closes its dialog.
- **Fallback:** if there's no Wayland session or the plugin isn't
  listening when the pinentry starts, it `exec`s `pinentry-gnome3` (or
  `pinentry-curses` without a display) with the same arguments, before
  saying anything to gpg-agent. `OMAPIN_FALLBACK` picks another
  program. If the shell goes away in the middle of a session, the pending
  prompt counts as cancelled.

### Protocol between the two halves (v2)

Request: `{"v":2,"type":"getpin"|"confirm"|"message","title","desc","prompt","error","ok","cancel","notok","repeat","repeatError","timeout"}`
(empty fields are omitted; `repeat` is the second field's placeholder;
`timeout` is in seconds, at most 86400).

Response: `{"result":"ok"|"cancel"|"notok"|"timeout"|"busy"|"error","pin"?,"message"?}`.
`pin` is the UTF-8 PIN, percent-encoded (`encodeURIComponent`). The binary
therefore parses it without any JSON unescaping, which would leave
unwiped copies. The plugin refuses requests from any other protocol
version, so a binary and a plugin from different releases can never pass
a PIN the other misreads. A misread PIN would still be sent to the card
and use up a try.

### Security notes

See [SECURITY.md](SECURITY.md) for the threat model and how to report a
vulnerability. In short:

- **Memory:** the binary locks its memory (`mlockall`) and turns off core
  dumps and ptrace (non-dumpable). Every copy of the PIN it makes lives in
  a zeroized buffer: the socket read buffer, the decoded PIN and the
  encoded `D` lines. It writes to gpg-agent unbuffered, so no stdio buffer
  keeps the PIN.
- **Socket:** it lives in the user's 0700 runtime directory, and the
  binary checks that the listening peer runs as the same user.
- **Displayed text:** texts from gpg-agent are stripped of control
  characters and bidirectional overrides (so a key's user ID can't
  disguise what is shown), and they are rendered as plain text, never
  rich text.
- **Assuan output:** responses to gpg-agent never carry raw control
  characters, so nothing the dialog says can inject protocol lines.
- **Inside omarchy-shell:** the PIN goes through a QML `TextInput` and the
  JavaScript heap, which can't be wiped. The fields are cleared as soon as
  the answer is sent. This is the same trade-off as the polkit dialog.

## Install

The pinentry needs both halves: the `omapin` binary, which gpg-agent runs,
and the shell plugin. There are two packages, which install the same files
under their prefix: the binary (`bin/omapin`) and the shell plugin
(`share/omapin/plugin`). Install one of them, then do the per-user steps.

### Arch/Omarchy (PKGBUILD)

```sh
just pkg                                  # packaging/omapin-*.pkg.tar.zst
sudo pacman -U packaging/omapin-*.pkg.tar.zst
```

The prefix is `/usr`. The package replaces `pinentry-omarchy`.

### Nix (flake)

```sh
nix profile add github:lbssousa/omapin
```

The prefix is `~/.nix-profile`. In a flake, use `packages.<system>.default`
or the `overlays.default` overlay (`pkgs.omapin`). The fallback
pinentries come from nixpkgs (`pinentry-gnome3`, `pinentry-curses`).

The flake also has modules that do the per-user steps below, both as
`programs.omapin`:

- `homeModules.default` (Home Manager, also standalone on Omarchy):
  installs the package, links the plugin into
  `~/.config/omarchy/plugins/`, points
  `services.gpg-agent.pinentry.package` at it (with
  `services.gpg-agent.enable`), and enables the plugin in the running
  shell on activation (`programs.omapin.enablePlugin`).
- `nixosModules.default`: installs the package, points
  `programs.gnupg.agent.pinentryPackage` at it (with
  `programs.gnupg.agent.enable`), and links the plugin for every user
  (`systemd.user.tmpfiles`). Enable the plugin in the shell yourself, or
  with the Home Manager module.

```nix
{
  inputs.omapin.url = "github:lbssousa/omapin";
  # Home Manager:
  #   imports = [ inputs.omapin.homeModules.default ];
  #   programs.omapin.enable = true;
}
```

### Per user

With `prefix` set to `/usr` or `$HOME/.nix-profile`:

```sh
ln -sfn "$prefix/share/omapin/plugin" ~/.config/omarchy/plugins/lbssousa.omapin
omarchy-shell shell enablePlugin lbssousa.omapin '{}'
echo "pinentry-program $prefix/bin/omapin" >> ~/.gnupg/gpg-agent.conf
gpgconf --reload gpg-agent
```

### The plugin alone

The repository root is also the plugin, so the Omarchy plugin marketplace
and `omarchy plugin add` can install it:

```sh
omarchy plugin add https://github.com/lbssousa/omapin.git --enable
```

That installs only the dialog: it still needs the `omapin` binary from one
of the packages above, and the `pinentry-program` line. Use either this or
the package's link in `~/.config/omarchy/plugins/lbssousa.omapin`, not
both. Update with `omarchy plugin update lbssousa.omapin`.

## Remove

Undo the per-user steps, then remove the package:

```sh
sed -i '\|^pinentry-program .*/omapin$|d' ~/.gnupg/gpg-agent.conf
gpgconf --reload gpg-agent
omarchy plugin remove lbssousa.omapin   # unlinks the package's plugin, or deletes the cloned one
sudo pacman -R omapin                    # or: nix profile remove omapin
```

With the flake modules, set `programs.omapin.enable = false` and switch
instead. gpg-agent goes back to its default pinentry.

## Releases

`main` only takes squash-merged pull requests, which GitHub signs with its
own key. A release is therefore a **GPG-signed tag** made by the
maintainer on the merged commit. That tag, not `main`, is what should be
deployed: check it out and verify it against the maintainer's key
(`git verify-tag vX.Y.Z`) before building.

1. Open a PR that bumps the version in `Cargo.toml` (then run
   `cargo update -w`), `packaging/PKGBUILD` and `manifest.json`.
   The same PR turns the "Unreleased" section of
   [CHANGELOG.md](CHANGELOG.md) into the new version's release notes.
   Merge it.
2. Tag the merge commit and push the tag:
   ```sh
   git switch main && git pull
   git tag -s vX.Y.Z -m "omapin X.Y.Z"
   git push origin vX.Y.Z
   ```

## Development

| Recipe | What it does |
|---|---|
| `just test` | Unit tests, integration tests against a fake dialog, `cargo fmt --check` and clippy |
| `just test-plugin` | Protocol tests against the real QML plugin in a throwaway Quickshell instance (needs the Wayland session; dialogs flash on screen) |
| `just fuzz [target] [secs]` | Fuzzes the Assuan session, the dialog-reply parser or the `D`-line encoder with cargo-fuzz (needs nightly Rust and `cargo install cargo-fuzz`) |
| `just dev` | Runs the dialog in a separate Quickshell instance on its own socket (from `dev/shell.qml`, built in a temporary folder that links the plugin's QML and the shell's `Commons`/`Ui`; the checkout carries no symlinks, which plugins may not have) |
| `just try` | Sends a sample `GETPIN` through the `just dev` instance |
| `just link` | Loads this checkout's plugin in the real shell (restarts omarchy-shell) |
| `just pkg` | Builds the Arch package |
| `just nix` | Builds the Nix package into `./result` (runs the tests too) |

omarchy-shell doesn't reload a `keepLoaded` service when its files change,
and its file watcher doesn't follow the plugin symlink. Iterate with
`just dev`, and restart the shell when you're done.

## Feedback and contributing

- **Bugs and feature requests:** [GitHub issues](https://github.com/lbssousa/omapin/issues).
- **Security vulnerabilities:** report them privately, as described in
  [SECURITY.md](SECURITY.md).
- **Contributions:** pull requests are welcome. See
  [CONTRIBUTING.md](CONTRIBUTING.md) for the rules: tests with every change,
  signed commits, and CI passing.
- **Release notes:** [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE).
