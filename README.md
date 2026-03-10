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

- `~/.config/ravy/secrets.sh`
- `~/.config/ravy/secrets.fish`
- `~/.config/ravy/private.gitconfig`
- `~/.config/ravy/ssh.config`
- `~/.config/ravy/docker-compose.yml`
- `~/.config/ravy/singbox/singbox.base.jsont`
- `~/.config/ravy/credentials/maxdevel-adacfa618c67.json`
- `~/.config/rclone/rclone.conf`

For day-to-day use after your shell reloads:

- `chez` is a short alias for the public `chezmoi` source
- `chezp` targets the private `RAVY_PRIVATE_HOME` source automatically

Examples:

```sh
chez status
chezp edit ~/.config/ravy/secrets.fish
chezp apply ~/.config/ravy/secrets.fish
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

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://www.iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
