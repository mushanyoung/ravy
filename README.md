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

Ravy uses **Herdr TUI 0.9.5**, pinned in mise. Herdr owns SSH connections,
agent forwarding renewal, session discovery, and reconnect. `cloudtop` and `cl`
are argv-only aliases; there is no custom SSH transport, socket repair, polling
plugin, or editor mode-switching hook.

```sh
cl                            # local Herdr session
cl dev-host                   # herdr --remote dev-host (SSH config alias)
cl dev-host --session work     # named remote session
cl --session work             # named local session
```

Install Ravy and its mise tools on each endpoint before use. `cloudtop` requires
Herdr on PATH; remote shell discovery and any remote-binary preparation are native
Herdr behavior. Herdr's managed SSH configuration is enabled; keep host aliases
and intended `ForwardAgent yes` policy in your existing SSH config. Enable it only
for trusted development hosts that need Git authentication or SSH signing; keep
forwarding disabled on servers that do not need it. Herdr does not enable agent
forwarding for you. Shell startup preserves inherited `SSH_AUTH_SOCK`; it no
longer overrides it with `~/.ssh/ssh_auth_sock`. No private keys are copied.

The old `--mosh`, `--tmux`, `--zellij`, and `--ssh` transport selectors are rejected.
Mosh roaming is not provided by this SSH migration. `CLOUDTOP_*` overrides no
longer control transport, sessions, or agent sockets.

### Daily operation and ownership

Keep frequently used trusted development machines in Herdr's native sidebar:

```sh
herdr machine add mac-dev --remote-session default
herdr machine add linux-dev --remote-session default
cl
```

These are example SSH aliases, not machines automatically provisioned by Ravy.
Use `herdr machine ...` directly for management: `cl machine ...` would treat
`machine` as a host. Use `cl linux-server --session ops` for an on-demand server;
there is no need to enroll every server for background connections. A saved
machine targets one remote session. Cloudtop does not keep another host inventory
or generate session names.

Install Ravy separately on each endpoint. Herdr does not synchronize remote Fish,
configuration or custom commands such as the tab-10 helper. Existing Ctrl+Space,
pane navigation, detach, and cwd-follow/home shortcuts remain in Herdr's config.

### Accepted agent lifecycle and remaining rollout gates

The operating contract keeps the local agent stable, lets Herdr handle ordinary
reconnections, and uses explicit transport recovery after rare local-agent
replacement. A live OpenSSH master retains the agent from its creation; reattaching
with a new `SSH_AUTH_SOCK` does not rebind it. This is an accepted compatibility
limitation, not a requirement to disable native connection reuse or fix upstream
before migration. The old Cloudtop used `ssh -S none` and a remote stable symlink;
remote forwarded-socket rotation did not imply local-agent replacement.

Required Linux server/developer E2E pass. The strict hot-replacement diagnostic is
retained separately as `make diagnose-herdr-agent-rotation`; on 0.9.5 it still
fails with a nonzero exit, without skip/xfail or `continue-on-error`. It is opt-in
in CI and is not a required acceptance gate under the agreed operating contract.
No production launcher resets masters or repairs sockets.

**Live rollout remains pending:** the native macOS CI job has not run, and actual
terminal/host checks (IME, clipboard, sleep/wake, WAN loss) remain outstanding.
No live deployment or push is implied by passing local tests. See the
[test contract and scoped recovery procedure](tests/README.herdr.md).

### Familiar keys

Press `Ctrl+Space` and release before the next key:

- `n`: new tab following cwd; `c`: new tab in home.
- `h/j/k/l` or arrows: focus pane; `%` / `"`: vertical / horizontal split.
- `o`: next pane; `z`: zoom; `x`: close pane with confirmation.
- `p` / `Shift+n`: previous / next tab; `,`: rename tab.
- `1…9`, or direct `Alt+1…9`: numbered tab; direct `Alt+0`: tab 10.
- `d`: detach; `[`: copy mode; `e`: edit scrollback.
- `Shift+w`: new workspace; native `w`: workspace picker.

Herdr uses prefix commands instead of the old Zellij modal/autolock machinery.
Direct Alt keys remain reserved even inside editors and agents. The tiny managed
`~/.local/bin/ravy-herdr-tab-10` helper fills the native 1…9 range gap using native
list/focus commands; it does not manage sessions. The home-tab command also calls
the native CLI. Python 3 is needed for the tab-10 adapter. Built-in worktree
create/delete shortcuts are disabled: open canonical worktrees created outside
Herdr instead. Ctrl+V is left to terminal applications.

### Persistence and deliberate updates

Detach or client loss leaves live server processes running. A server restart
restores layout with fresh shells; it cannot preserve the old processes.
Automatic agent resume and experimental pane-history persistence are disabled.
Layout restoration is still native Herdr behavior, unlike the old policy of
removing saved Zellij state. No automatic agent or paid-model invocation is added.
Version and agent-manifest background checks are disabled; this is not a claim
that every possible Herdr feature is network-free. Upgrade the pinned version
only after rerunning the real-terminal and SSH tests.

### Moving an existing installation

Review/apply the Herdr config, tab helper, shell templates, Neovim changes and mise
pin together through the normal chezmoi workflow. Finish or deliberately stop old
Zellij work first: live PTYs cannot be moved into Herdr. Start **fresh Herdr
sessions** so they receive native agent-socket management; do not import an old
shell's exported stable-socket override.

Removing source entries does not necessarily remove previously deployed files.
After old sessions finish, inspect and explicitly retire stale Zellij config/plugin
files, the old `zellij-safe-detach` entrypoint, Cloudtop caches/socket backups and
any obsolete Zellij package installation. This branch does not automatically
kill old sessions, delete caches, or change a live machine. Leave private SSH/Git
identity configuration untouched. Rollback requires the old repository ref and
its tool version; it does not transfer newly running Herdr processes back.

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
missing. See [isolation, coverage and current results](tests/README.herdr.md).

## Recommended Setup

For the best experience, we recommend:

- [**iTerm2**](https://iterm2.com/)
- [**nerd-fonts**](https://github.com/ryanoasis/nerd-fonts)
