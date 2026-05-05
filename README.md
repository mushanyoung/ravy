# Ravy

**Ravy** is a cross-platform dotfiles setup managed with `chezmoi`.

## Installation

Public-only install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/master/install.sh | bash -s
```

Public + private install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/master/install.sh | \
  RAVY_PRIVATE_REPO=git@github.com:mushanyoung/custom.git bash -s
```

Optional bootstrap helpers stay opt-in:

```sh
RAVY_BOOTSTRAP_OPTIONAL=1 ./install.sh
```

If the private repo is already checked out locally, point the bootstrap at it:

```sh
RAVY_PRIVATE_HOME="$HOME/.local/share/ravy-private" ./install.sh
```

## Nushell Path

`~/.config/nushell` is the canonical Nushell config path on both Linux and macOS.

- Linux reads `~/.config/nushell/{env,config,login}.nu` directly.
- macOS keeps thin shims in `~/Library/Application Support/nushell/{env,config,login}.nu` that source the canonical files.
- macOS keeps `~/Library/Application Support/nushell/history.txt` as a symlink back to `~/.config/nushell/history.txt`.

After `chez apply` or `./install.sh`, restart Nushell to pick up updated config.

For SSH remote commands, note that `sshd` invokes the login shell with `-c`.
When the login shell is `nu`, that path does not automatically load
`~/.config/nushell/env.nu`, so PATH-dependent commands such as Homebrew installed binaries
may be missing. The bundled `cloudtop` helper routes through `/bin/sh -lc`
and probes common Homebrew install prefixes before attaching to zellij by
default. Use `cloudtop --mosh` for mosh transport and `cloudtop --tmux` for a
tmux session. The shorter `cl` command is a shim for `cloudtop`. Running
`cloudtop` or `cl` without a host attaches to a local session without opening
an SSH connection.

For SSH transport, `cloudtop` bypasses SSH connection sharing and refreshes or
repairs a stable forwarded-agent socket at `~/.ssh/ssh_auth_sock` before
attaching. New interactive shells in long-lived remote sessions prefer that
socket when `SSH_CONNECTION` is present, so Git operations continue to use the
current forwarded key after reconnects. Existing panes may need
`export SSH_AUTH_SOCK=$HOME/.ssh/ssh_auth_sock` once.

## Private Bootstrap

Private files are managed by the private `custom` repo as an `age`-encrypted
`chezmoi` source.

On a fresh machine:

1. Clone the public repo and the private repo.
2. Run `./install.sh` from the public repo.
3. If `~/.config/chezmoi/key.txt` does not exist yet, the script decrypts the
   private bootstrap key from `custom/bootstrap/key.txt.age` and prompts once
   for its passphrase.
4. The script applies the public repo, then applies the private repo with
   `chezmoi apply -S "$RAVY_PRIVATE_HOME"`.

Managed private targets now include:

- `~/.config/ravy/secrets.tsv`
- `~/.config/ravy/secrets.sh`
- `~/.config/ravy/secrets.fish`
- `~/.config/ravy/private.gitconfig`
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

Examples:

```sh
chez diff
chez apply
chez private edit ~/.config/ravy/secrets.tsv
```

## Neovim

Once installed, open Neovim and install plugins:

```
:PlugUpdate
```

## Testing

```sh
make test
```

`make test` now covers bash, zsh, fish, Nushell, the macOS Nushell harness, install, and Neovim rendering.

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://www.iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
