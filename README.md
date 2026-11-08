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

Shell startup uses the source directory and Homebrew metadata resolved by
`chezmoi apply`; it discovers them again if the checkout moves or a different
`brew` executable is found. `RAVY_HOME` remains an explicit override. Reapply
after moving either installation to refresh the generated paths. Noninteractive
fish uses `mise activate fish --shims`, which respects mise's configured shims
directory without installing interactive hooks.

The shared Bash, Zsh and Fish setup runs `umask go-w` to prevent group/other
writes on new files. An inherited `0002` becomes `0022`, while stricter masks
such as `0027` and `0077` are preserved. Child processes inherit the resulting
mask; existing shells need their config reloaded, and existing file permissions
are unaffected.

Neovim preserves trailing blank lines and leaves Markdown and diff whitespace
intact. A project's EditorConfig takes precedence; other buffers can opt out of
the default trailing-space cleanup with `vim.b.ravy_trim_whitespace = false`.
Unicode BOMs and UTF-8 are detected automatically, with Latin-1 as a fallback.
Open ambiguous legacy encodings explicitly, for example `:edit ++enc=gbk file`
or `:edit ++enc=utf-16le file`.

## Herdr TUI and Cloudtop

See [usage and design](docs/herdr.md) and the [real-terminal test contract](docs/herdr-testing.md).

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
5. The script runs `custom/install.sh` when present, refreshes the public mise
   include after the private checkout is available, then runs `mise install`
   from `$HOME`. This includes private tools on the first installation too.

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

`make test` covers bash, zsh, fish, install, Neovim rendering, Herdr configuration,
the tab adapter, and Cloudtop argv compatibility. Python 3.11+ is required.
Use a narrower target such as `make test-nvim` when iterating on one area.

`make lint-herdr` runs ShellCheck and Ruff (CI pins Ruff 0.14.3).
`make test-e2e-server` uses real Herdr, PTYs, Neovim and a private loopback sshd on
Linux. `make test-e2e-developer` uses real SSH/agent signing and runs on macOS or
Linux. These are separate from fast unit tests and fail when a prerequisite is
missing. See [isolation, coverage and current results](docs/herdr-testing.md).

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)

## Development

Start with [AGENTS.md](AGENTS.md), then read the task-specific documents it links.
