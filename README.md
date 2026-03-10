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

## Local Secrets

Keep machine-local secrets outside Git:

- `~/.config/ravy/local.sh`
- `~/.config/ravy/local.fish`

Example files are installed at:

- `~/.config/ravy/local.sh.example`
- `~/.config/ravy/local.fish.example`

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
