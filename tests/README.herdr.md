# Herdr migration tests and rollout gate

## Current candidate status

Herdr TUI is pinned to **0.9.5**. The migration is implemented but **not approved
for live rollout**. No live chezmoi installation or private repository is changed
by the tests. Publication and deployment are separate actions.

Observed on Linux aarch64 with real Herdr 0.9.5 and chezmoi 2.74.0:

- `make test`: passes Fish/Bash/Zsh, installer, Neovim rendering, 8 Herdr
  config/adapter unit tests and 9 Cloudtop unit tests. The existing optional
  native prompt integration reports a skip when zoxide/starship are absent.
  The container also reports pre-existing unavailable `en_US.UTF-8` locale
  warnings in the shell suite; these are not Herdr failures.
- `make lint-herdr`: ShellCheck and Ruff pass.
- `make test-e2e-server`: 4 real-path tests pass.
- `make test-e2e-developer`: 2 pass, 1 fails at the strict agent-replacement
  gate described below. The target exits nonzero; it is not an expected-failure
  test and the workflow has no `continue-on-error`.
- The workflow YAML, shell blocks and exact pinned-binary download/checksum step
  were exercised locally on Linux aarch64. GitHub Actions itself has not run for
  this branch. Neither the macOS runner nor cross-OS connections have been tested.

The next acceptance step is to resolve the native agent-replacement issue and
run the actual macOS job. GUI-terminal IME, enhanced keyboard protocols, clipboard,
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

`make test-e2e-developer` runs natively on Linux or macOS:

1. Real SSH and native remote server startup, forwarded-agent signature creation
   and verification, ordinary reattach, and signing in old/new panes.
2. Agent replacement at a new socket with a fresh SSH transport: signing works
   in old/new panes without a Ravy stable-socket bridge.
3. Agent replacement with the native shared SSH transport still alive: signing
   must work after reattach. This currently fails with 0.9.5 and blocks rollout.

CI runs Linux/server, Linux/developer and macOS/developer as independent jobs.
The macOS job uses macOS processes and sshd, not a Linux mock. Each remote endpoint
is a separate sshd/Herdr process tree with a private HOME on the same runner;
these are real loopback SSH tests, not claims of WAN or cross-OS validation.

## Reproduction

Prerequisites: Python 3.11+, Herdr 0.9.5, chezmoi, Fish, OpenSSH client/agent/sshd;
Neovim is additionally required for the server series. Lint uses ShellCheck and
Ruff 0.14.3. CI verifies pinned Herdr/chezmoi assets before execution.

Run from the repository using a trusted toolchain PATH and an isolated HOME:

```sh
root=$(mktemp -d "${TMPDIR:-/tmp}/ravy-herdr.XXXXXX")
mkdir "$root/home"
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make lint-herdr test
# Run each separately so a failing developer gate does not hide server results.
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make test-e2e-server
env -i HOME="$root/home" TMPDIR="$root" PATH="$PATH" \
  PYTHONDONTWRITEBYTECODE=1 make test-e2e-developer
```

Use a short temporary root to respect Unix socket length limits. The test harness
removes its own nested temporary directories; remove the empty outer root/home
after inspecting any failure. Missing prerequisites fail rather than skip.

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
experiment only. No production launcher invokes it. Do not restore custom SSH
socket repair, silently disable native SSH management, skip the failing case, or
claim full migration acceptance merely to obtain green CI. A version change or
an explicitly accepted operational restriction needs a separate decision and
must rerun this regression.

## Isolation and cleanup

The harness renders real Ravy Fish startup and copies the managed Herdr config
and adapter into temporary homes. It launches real Herdr, PTYs, localhost-only
sshd and foreground ssh-agent processes. It creates only temporary Ed25519 keys,
pins the test host key, disables password authentication, and forces the test SSH
identity into the isolated remote HOME/config. It does not load user keys or call
an LLM. No private keys or raw environment dumps become test artifacts.

Cleanup stops fixture clients/servers/agents/sshd, verifies the server stopped,
and closes only the exact config+target-namespaced shared SSH master. Herdr itself
places its shared master socket under `/tmp/hssh-UID`; that native path is outside
TMPDIR. The harness neither deletes that shared directory nor stops unrelated
masters. A forced kill of the harness itself can bypass normal cleanup; inspect
only the identified fixture processes and directories, never use a global pkill.
