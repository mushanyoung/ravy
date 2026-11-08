# Ravy

**Ravy** is a cross-platform dotfiles setup managed with `chezmoi`.

The repository root holds project tooling, documentation and `bin/` commands.
`.chezmoiroot` selects `chezmoi/` as the public configuration source. Optional
`custom/` stays a separate private repository beside it. Existing chezmoi clones
keep their sourceDir pointing at this repository root; no local setting change
is required. See the [layout and private overlay contract](docs/private-overlay.md).

## Installation

Requires macOS or Linux, `git`, and `curl`. The installer sets up mise,
chezmoi, Homebrew packages and shell configs, then makes fish the login shell.
Set `RAVY_SKIP_CHSH=1` to keep your current shell.

Public-only install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/main/install.sh | bash -s
```

Public + private install:

```sh
curl -fsSL https://raw.githubusercontent.com/mushanyoung/ravy/main/install.sh | \
  RAVY_PRIVATE_REPO=git@github.com:mushanyoung/custom.git bash -s
```

New installs use `~/.ravy`, with the optional private repo in `~/.ravy/custom`.
Existing installs keep their location. The private repo needs Git access
(including a forwarded SSH agent); encrypted bootstrap keys prompt for a passphrase.
See [options and migration](docs/installation.md) for custom paths or moving an
existing checkout to `~/.ravy`.

## Herdr TUI and Cloudtop

See [usage and design](docs/herdr.md) and the [real-terminal test contract](docs/herdr-testing.md).

## Private configuration

The optional `custom/` repo manages encrypted files with its own chezmoi config
and state. Existing private checkouts are reused; `RAVY_PRIVATE_REPO` enables
clone/update. See the [private overlay contract](docs/private-overlay.md).

After reloading your shell:

```sh
chez diff                                      # public, then private
chez apply
chez private edit ~/.config/ravy/secrets.tsv    # private only
```

`ravy` opens the public checkout; `ravyprivate` / `ravyc` open the private one.
`chezp` is an alias for `chez private`.

## Neovim

Once installed, open Neovim and install plugins:

```vim
:Lazy sync
```

Neovim preserves trailing blank lines and leaves Markdown and diff whitespace
intact. A project's EditorConfig takes precedence; other buffers can opt out of
the default trailing-space cleanup with `vim.b.ravy_trim_whitespace = false`.
Unicode BOMs and UTF-8 are detected automatically, with Latin-1 as a fallback.
Open ambiguous legacy encodings explicitly, for example `:edit ++enc=gbk file`
or `:edit ++enc=utf-16le file`.

## Testing

```sh
make setup
make check
```

The locked toolchain checks formatting, lint, Python types, unit/config tests,
real PTY/SSH workflows and an isolated production render. See the
[quality commands and platform prerequisites](docs/testing.md) and
[Herdr test contract](docs/herdr-testing.md). `make format` applies formatters.

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)

## Development

Start with [AGENTS.md](AGENTS.md), then read the task-specific documents it links.
