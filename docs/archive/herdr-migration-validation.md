# 历史记录（不代表当前验证状态）

来源：迁移至 docs/ 前的 tests/README.herdr.md。仅供追溯。

# Herdr migration tests and rollout gate

## Current candidate status

Herdr TUI is pinned to **0.9.5**. The migration is implemented but **not approved
for live rollout**. No live chezmoi installation or private repository is changed
by the tests. Publication and deployment are separate actions.

Observed on Linux aarch64 with real Herdr 0.9.5 and chezmoi 2.74.0:

- `make test`: passes Fish/Bash/Zsh, installer, Neovim rendering, 8 Herdr
  config/adapter tests, 4 E2E-selection tests and 9 Cloudtop tests. The existing optional
  native prompt integration reports a skip when zoxide/starship are absent.
  The container also reports pre-existing unavailable `en_US.UTF-8` locale
  warnings in the shell suite; these are not Herdr failures.
- `make lint-herdr`: ShellCheck and Ruff pass.
- `make test-e2e-server`: 4 real-path tests pass.
- `make test-e2e-developer`: both required real SSH tests pass.
- `make diagnose-herdr-agent-rotation`: 1 strict diagnostic fails specifically
  after replacement with a reused master. Python exits 1 and make exits 2. This
  is not a passing expected-failure test; no skip/xfail or `continue-on-error`.
- The workflow YAML, shell blocks and exact pinned-binary download/checksum step
  were exercised locally on Linux aarch64. GitHub Actions itself has not run for
  this branch. Neither the macOS runner nor cross-OS connections have been tested.

The SSH fixture isolation fix was verified locally on macOS arm64 (both developer
tests) and in an Ubuntu 24.04 arm64 container (both developer tests and all four
server tests). Runtime directories stay under `/tmp`; a real SSH preflight checks
shell startup isolation. Five additional regression tests cover environment lookup,
temporary-directory selection and cleanup, unsafe account-home permissions, and
unsupported login shells. This is separate from the still-pending macOS GitHub
Actions run.

After the remote-keymap fix, the developer series has three required tests; all
pass on macOS arm64 and Ubuntu 24.04 arm64, including remote home-tab/tab-10
commands. The four Linux server tests still pass, and the Cloudtop argv suite
now has eleven passing tests on macOS. The launcher preserves explicit keymap
overrides and only adds its server-keymap default to remote connections.

The automatic-title change passes 15 Herdr config/adapter tests, the Fish config
suite, the local macOS PTY/restore tests and all three macOS developer tests.
Ubuntu 24.04 arm64 passes all three developer tests and the expanded five-test
server suite. Linux foreground detection explicitly ignores exited zombies,
which Herdr 0.9.5 can still include in `pane.process_info`. Ruff 0.14.3 and
ShellCheck pass. These are local test results, separate from GitHub Actions.

The agreed contract accepts rare local-agent replacement as an explicit recovery
operation, while retaining native connection reuse. It does not require transparent
hot replacement through a still-live SSH master. The next platform acceptance step
is to run the actual macOS job. GUI-terminal IME, enhanced keyboard protocols, clipboard,
laptop sleep/wake and real WAN loss still require checks on the intended terminal
and hosts. Injected UTF-8 PTY bytes do not prove a GUI IME works.

## Two test series

`make test-e2e-server` is Linux-only:

1. Real PTY `Ctrl+Space`, cwd-follow/home tabs, splits, h/l focus, direct Alt
   tab navigation including tab 10, detach and reattach.
2. Live command survival after client termination; server restart restores
   layout with fresh shells, without resurrecting the old command.
3. Real Neovim survives detach; UTF-8 input reaches the editor and is saved.
4. Native remote server startup over real OpenSSH, forced loss of fixture SSH
   child processes, continued server work, reconnect and clean detach.
5. Automatic numbered titles: HOME, leaf directories with spaces, foreground
   versus background jobs, focused split panes, manual names, moving/closing
   tabs, worker singleton/restart, and worker cleanup when its server stops.
   The server-restart test also verifies automatic titles resume after restore.

`make test-e2e-developer` runs natively on Linux or macOS:

1. Real SSH and native remote server startup, forwarded-agent signature creation
   and verification, ordinary reattach, and signing in old/new panes.
2. Agent replacement at a new socket with a fresh SSH transport: signing works
   in old/new panes without a Ravy stable-socket bridge.
3. Remote `Ctrl+Space n` follows cwd, `Ctrl+Space c` creates a tab in the remote
   HOME, and `Alt+0` selects tab 10. This exercises custom commands over real SSH;
   Herdr's default `--remote-keybindings local` disables those commands, so the
   launcher defaults to `--remote-keybindings=server`.
   This also verifies remote HOME/directory/process titles and that `Alt+0`
   still selects the tenth displayed tab after closing and creating tabs.

`make diagnose-herdr-agent-rotation` is a separate, opt-in compatibility diagnostic:

1. Agent replacement with the native shared SSH transport still alive: retain
   the original assertion that signing works after reattach. This still fails
   with 0.9.5; it is outside the accepted operating contract, not a suppressed
   failure in the required developer suite.

Default CI runs Linux/server, Linux/developer and macOS/developer as independent jobs.
Manual `herdr-e2e` workflow dispatch can enable the boolean `agent_rotation` input
(default false). This runs the strict diagnostic after required tests in both
developer jobs; a diagnostic failure makes that explicitly requested job red.
There is no automatic master reset or changed signing assertion to produce green CI.
The macOS job uses macOS processes and sshd, not a Linux mock. Each remote endpoint
is a separate sshd/Herdr process tree with a private HOME on the same runner;
these are real loopback SSH tests, not claims of WAN or cross-OS validation.

## Reproduction

Prerequisites: Python 3.11+, Herdr 0.9.5, chezmoi, Fish, OpenSSH client/agent/sshd;
Neovim is additionally required for the server series. Lint uses ShellCheck and
Ruff 0.14.3. CI verifies pinned Herdr/chezmoi assets before execution.
The SSH account's login shell must be Fish, Bash, Zsh, sh or dash. Its passwd home
must be owned by that account and not group/world-writable; the harness reports
an error before starting sshd if these requirements are not met.

Run from the repository using a trusted toolchain PATH and an isolated HOME:

```sh
root=$(mktemp -d /tmp/ravy-herdr.XXXXXX)
mkdir "$root/home"
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make lint-herdr test
# Run required series separately so one failure does not hide the other results.
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make test-e2e-server
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make test-e2e-developer
# Optional: known nonzero result on 0.9.5; report separately from required gates.
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make diagnose-herdr-agent-rotation
```

The E2E harness creates short, mode-0700 runtime directories directly under `/tmp`,
independent of `TMPDIR`, to avoid socket-length limits and ancestor tool configs.
For each SSH fixture it also creates a mode-0700 `.ravy-herdr-keys-*` directory
inside the account's real passwd home, containing only the generated authorized
public key (mode 0600). It uses the passwd home even when the caller overrides
`HOME`. `StrictModes yes` remains enabled: putting the authorized key in `/tmp`
would make sshd reject its writable ancestor. Existing SSH files are untouched.
Both directories are removed by test cleanup; remove the outer root/home above
after inspecting results. Missing prerequisites fail rather than skip.

For a rootlessly unpacked Linux OpenSSH package, the harness accepts the exact
`RAVY_TEST_SSHD`, `RAVY_TEST_SSHD_SESSION`, `RAVY_TEST_SSHD_AUTH` and
`RAVY_TEST_SSHD_LIB_DIR` paths. These affect only the test daemon; normal installed
sshd and macOS need no such overrides. Pass them explicitly through `env -i`.

## Agent-replacement failure: causal evidence

Reproduction replaces a generated test key and the local agent socket while the
native SSH master persists. Ordinary reconnect keeps the old master alive and
`ssh-add -T` in the existing remote pane reports agent communication failure.
The test uses a different key so a stale agent cannot falsely pass.

Changing only the connection condition fixes the same test: close the fixture's
exact SSH master, then attach again. The existing pane can now use the replacement
agent; a newly created pane also passes. This identifies transport reuse as the
relevant boundary rather than shell startup overriding `SSH_AUTH_SOCK`.

In the version-bound upstream source, `apply_managed_ssh_options` adds
`ControlMaster=auto` and `ControlPersist=600`; `shared_ssh_control_path` namespaces
the shared master by configuration path and target, not by the current agent
socket. An existing master retains its old forwarding context. See:

- [v0.9.5 remote attach source](https://github.com/herdrdev/herdr/blob/v0.9.5/src/remote/attach.rs)
- [v0.9.5 shared SSH socket source](https://github.com/herdrdev/herdr/blob/v0.9.5/src/platform/unix_common.rs)

The fixture's `close_ssh_master` exists for cleanup and the fresh-transport control
experiment only. No production launcher invokes it. The user accepted the stable
local-agent contract and explicit recovery exception; test selection, CI and docs
now implement that decision together. The diagnostic was rerun and still fails.
Do not restore custom socket repair, disable native SSH management, weaken signing
assertions, or infer complete migration acceptance from required Linux tests.
Rerun required suites and this diagnostic on version or lifecycle-policy changes.

## Scoped recovery after local-agent replacement

Ordinary detach/reattach needs no Cloudtop action. For saved-machine authentication
problems use native `herdr machine status <label-or-id> --json` and, when appropriate,
`herdr machine reconnect <label-or-id>` in an interactive terminal. Reconnect is
not a guaranteed master reset and does not install/update the remote Herdr server.

If the local agent was actually replaced and the old master still forwards to the
dead one:

1. Confirm the new agent works locally (`ssh-add -l`), then detach affected clients.
   Do not stop the remote Herdr server or its pane processes.
2. Identify the **exact** SSH target, Herdr-managed `-F` configuration, and shared
   `-S`/`ControlPath` from that connection's actual SSH invocation. Inspect process
   arguments only, never environment dumps. Verify the socket is owned by the
   current user, is a socket rather than a symlink, and belongs to this connection.
   If identity is ambiguous, stop; do not guess paths or scan/kill all masters.
3. Only with those verified values, check and close that master explicitly:

   ```sh
   # Set these to the verified connection values, not an arbitrary ~/.ssh/config.
   : "${managed_config:?}" "${control_path:?}" "${target:?}"
   # Proceed only after affected shared clients are accounted for.
   ssh -F "$managed_config" -S "$control_path" -O check "$target" &&
     ssh -F "$managed_config" -S "$control_path" -O exit "$target"
   ```

   Closing the master interrupts every client sharing that transport; a session
   name alone does not isolate it. Never use `pkill ssh`, delete the shared socket
   directory, or restart the remote Herdr server as a shortcut.
4. Reattach using the same target/session with the new local agent environment,
   then verify agent-backed signing in an existing pane and a new pane. A present
   socket or successful login alone is not proof of restored signing.

The automated fresh-transport test exercises this recovery boundary only inside
its disposable SSH fixture. Production master discovery/termination is deliberately
not implemented in Cloudtop. No host enrollment or live recovery was performed.

## Isolation and cleanup

The harness renders real Ravy Fish startup and copies the managed Herdr config
and adapter into temporary homes. It launches real Herdr, PTYs, localhost-only
sshd and foreground ssh-agent processes. It creates only temporary Ed25519 keys,
pins the test host key and disables password authentication. Before the account
shell starts, sshd `SetEnv` sets a separate bootstrap HOME, XDG directories,
ZDOTDIR, BASH_ENV and ENV. User SSH rc/environment files are disabled. A real SSH
preflight verifies the bootstrap startup marker for Fish/Bash/Zsh, and the forced
launcher checks its inherited lookup paths before selecting the rendered Ravy
home. sh/dash have no noninteractive user startup file to probe. Host system-wide
shell startup remains trusted; arbitrary login shells are rejected.

Herdr and rendering subprocesses run from fixture homes, with explicit XDG paths,
so they do not discover the checkout's ancestor tool configuration. The harness
does not load user keys or call an LLM. No private keys or raw environment dumps
become test artifacts.

Cleanup stops fixture clients/servers/agents/sshd, verifies the server stopped,
and closes only the exact config+target-namespaced shared SSH master. Herdr itself
places its shared master socket under `/tmp/hssh-UID`; that native path is outside
TMPDIR. The harness neither deletes that shared directory nor stops unrelated
masters. A forced kill of the harness itself can bypass normal cleanup, including
the generated public-key directory in the passwd home; inspect only the identified
fixture processes and directories, never use a global pkill.
