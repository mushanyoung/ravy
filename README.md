# Ravy

**Ravy** is a cross-platform dotfiles setup managed with `chezmoi`.

## Installation

`install.sh` requires `git`, bootstraps `mise` into `~/.local/bin` when needed,
uses mise to run `chezmoi` and `age`, applies the public source, installs
Homebrew on macOS or Linuxbrew on Linux when needed, installs packages from
`~/.config/homebrew/Brewfile`, switches the current user's login shell to the
brew-managed fish, applies the optional private source, then installs the
configured mise tools. Set `RAVY_SKIP_CHSH=1` to leave the login shell
unchanged.

Public-only install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/main/install.sh | bash -s
```

Public + private install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/main/install.sh | \
  RAVY_PRIVATE_REPO=git@github.com:mushanyoung/custom.git bash -s
```

For remote machines reached through SSH agent forwarding, the private clone uses
the forwarded agent exactly like a normal `git clone git@github.com:...`.
When `RAVY_PRIVATE_HOME` is not set, the private repo defaults to
`$RAVY_HOME/custom`, which is normally `~/.local/share/chezmoi/custom`.

## Cloudtop

The bundled `cloudtop` helper caches a small attach script on remote machines
under `~/.cache/cloudtop/<5-char-hash>/attach`, then enters `/bin/sh -lc` and
attaches to zellij. It checks `PATH`, `mise which zellij`, and common Homebrew
install prefixes. Use `cloudtop --mosh` for mosh transport.
The shorter `cl` command is a shim for `cloudtop`. Running `cloudtop` or `cl`
without a host attaches to a local session without opening an SSH connection.

For SSH transport, `cloudtop` bypasses SSH connection sharing and refreshes or
repairs a stable forwarded-agent socket at `~/.ssh/ssh_auth_sock` before
attaching. New interactive shells in long-lived remote sessions prefer that
socket when `SSH_CONNECTION` is present, so Git operations continue to use the
current forwarded key after reconnects. Existing panes may need
`export SSH_AUTH_SOCK=$HOME/.ssh/ssh_auth_sock` once.

## Zellij Mode Locking

Panes running an editor or a coding agent need raw keys, so zellij has to switch
to `locked` mode while one of them is focused and back to `normal` otherwise.
That is done by [`zellij-autolock`](https://github.com/fresh2dev/zellij-autolock),
a headless plugin declared in `dot_config/zellij/config.kdl.tmpl` and downloaded
by `chezmoi apply` through `.chezmoiexternal.toml` (pinned to a release asset and
verified by sha256). Add executables to its `triggers` list to lock for them —
they are matched by exact equality against the focused pane's full command and
against its executable basename, so list `vimdiff`, not `vim*`.

The first zellij session after installing it asks once to grant the plugin
`ReadApplicationState` and `ChangeApplicationState`; the grant is cached in
`permissions.kdl` under zellij's cache dir.

This replaced `bin/zellij-lock-watch`, a shell poller that ran two
`zellij action` commands every 0.2s in every session, forever. Each of those
opens two IPC connections to the session socket — one liveness probe from
`get_sessions()` plus one real connection — which measured about 18 connections
per second per session, roughly 600k over a 9 hour session.

Every one of those probes could destroy the session. `assert_socket()` in
`zellij-utils/src/sessions.rs` deletes the socket file when a connect returns
`ECONNREFUSED`, which is correct for a dead server but also happens on a live
one whose 128-deep accept backlog is momentarily full. The server then keeps
running with no socket, no client can ever reach it again, and the next
`zellij attach --create` silently starts a second server under the same name.
The plugin runs in-process inside the zellij server and opens no sockets.

Neovim also switches modes directly from `VimEnter`/`VimLeavePre` autocmds. That
is kept as a fallback for machines where the plugin is missing; it costs a couple
of connections per editor session rather than a steady stream.

## Private Bootstrap

Private files are managed by the private `custom` repo as an `age`-encrypted
`chezmoi` source.

On a fresh machine:

1. Run `install.sh` with `RAVY_PRIVATE_REPO` set when the private repo should be
   cloned automatically.
2. The private repo is cloned into `$RAVY_HOME/custom` unless
   `RAVY_PRIVATE_HOME` is set explicitly. Existing legacy checkouts at
   `~/.local/share/ravy-private` or `~/.ravy-private` are still detected.
3. If `~/.config/chezmoi/key.txt` does not exist yet, the script decrypts the
   private bootstrap key from `custom/bootstrap/key.txt.age` with mise-managed
   `age` and prompts once for its passphrase.
4. The script applies the public repo, then applies the private repo with
   `chezmoi apply -S "$RAVY_PRIVATE_HOME"`.
5. The script runs `custom/install.sh` when present, then runs `mise install`
   from `$HOME`. The rendered mise config includes `custom/mise/config.toml`
   when the private repo is available.

The optional private source is applied with its own chezmoi config/state files and
its checkout root is forced to mode `0700` before any private material is read.
Managed private targets now include:

- `~/.config/ravy/secrets.tsv`
- `~/.config/ravy/secrets.sh`
- `~/.config/ravy/secrets.fish`
- `~/.config/ravy/private.gitconfig`
- `~/.config/ravy/max-insights.gitconfig`
- `~/.config/ravy/git-allowed-signers`
- `~/.config/ravy/git-signing-key.pub`
- `~/.config/ravy/local-signing.gitconfig` (host-specific signing override)
- `~/.config/ravy/ssh.config`
- `~/.config/ravy/docker-compose.yml`
- `~/.config/ravy/singbox/singbox.base.jsont`
- `~/.config/ravy/credentials/maxdevel-adacfa618c67.json`
- `~/.config/rclone/rclone.conf`

For day-to-day use after your shell reloads:

- `chez apply`, `chez diff`, and `chez status` run against the public source
  first and then the private `RAVY_PRIVATE_HOME` source automatically when it
  is configured
- `chez private ...` targets the private `RAVY_PRIVATE_HOME` source explicitly
- `chezp` remains available as a compatibility alias for `chez private ...`
- `ravyprivate` and `ravyc` jump to the private source directory

Examples:

```sh
chez diff
chez apply
chez private edit ~/.config/ravy/secrets.tsv
```

## Neovim

Once installed, open Neovim and install plugins:

```vim
:Lazy sync
```

## Testing

```sh
make test
```

`make test` now covers bash, zsh, fish, install, Neovim rendering, zellij, and
cloudtop.
Use a narrower target such as `make test-nvim` when iterating on one area.

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
