# Herdr TUI and Cloudtop

Ravy uses **Herdr TUI 0.9.5**, pinned in mise. Herdr owns SSH connections,
agent forwarding renewal, session discovery, and reconnect. `cloudtop` and `cl`
are argv-only aliases; there is no custom SSH transport, socket repair, polling
plugin, or editor mode-switching hook.

```sh
cl                            # local Herdr session
cl dev-host                   # native SSH, using the remote server's keybindings
cl dev-host --session work     # named remote session
cl --session work             # named local session
```

Remote `cl`/`cloudtop` connections default to `--remote-keybindings=server`, so
the remote Herdr config supplies both built-in and custom bindings. Herdr's
native `local` mode omits custom commands: `Ctrl+Space c` and `Alt+0` do nothing
in that mode. An explicit `--remote-keybindings local` override is still passed
through. Existing connections need a detach/reattach to change modes; for an
older launcher, reconnect with `cl HOST --remote-keybindings server`.

Install Ravy and its mise tools on each endpoint before use. `cloudtop` requires
Herdr on PATH; remote shell discovery and any remote-binary preparation are native
Herdr behavior. Herdr's managed SSH configuration is enabled; keep host aliases
and intended `ForwardAgent yes` policy in your existing SSH config. Enable it only
for trusted development hosts that need Git authentication or SSH signing; keep
forwarding disabled on servers that do not need it. Herdr does not enable agent
forwarding for you. Shell startup preserves inherited `SSH_AUTH_SOCK`; it no
longer overrides it with `~/.ssh/ssh_auth_sock`. No private keys are copied.

The old `--mosh`, `--tmux`, and `--ssh` transport selectors are rejected.
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

Terminal/host checks (IME, clipboard, sleep/wake, WAN loss) require explicit
validation on the intended endpoints. Historical results are archived separately.
No live deployment or push is implied by passing local tests. See the
[test contract and scoped recovery procedure](herdr-testing.md).

### Familiar keys

Press `Ctrl+Space` and release before the next key:

- `n`: new tab following cwd; `c`: new tab in home.
- `h/j/k/l` or arrows: focus pane; `-`: horizontal split (top/bottom); `\`: vertical split (left/right).
- `o`: next pane; `z`: zoom; `x`: close pane with confirmation.
- `p` / `Shift+n`: previous / next tab; `,`: rename tab.
- `1…9`, or direct `Alt+1…9`: numbered tab; direct `Alt+0`: tab 10.
- `d`: detach; `[`: copy mode; `e`: edit scrollback.
- `Shift+w`: new workspace; native `w`: workspace picker.

Direct Alt keys remain reserved even inside editors and agents. The tiny managed
`~/.local/bin/ravy-herdr-tab-10` helper fills the native 1…9 range gap using native
list/focus commands; it does not manage sessions. The home-tab command also calls
the native CLI. Python 3 is needed for the tab-10 adapter. Built-in worktree
create/delete shortcuts are disabled: open canonical worktrees created outside
Herdr instead. Ctrl+V is left to terminal applications.

Tab titles always start with their current position: `1 ▶ nvim`, `2 repo/`,
`3 ~`. The name follows the foreground process in each tab's selected pane;
programs have a `▶` marker. An idle shell shows its final directory component
with a trailing `/`, except HOME stays `~` and the root directory stays `/`.
Background jobs do not change the name. Moving or closing tabs updates the
prefixes, matching `Alt+1…9` and `Alt+0` (the tenth tab in display order).
Manual names entered with `P ,` are preserved, with the number kept in front.
To return a manually named tab to automatic naming, use
`herdr tab rename TAB_ID ""`.

The managed `~/.local/bin/ravy-herdr-auto-title` helper starts from Fish inside
Herdr. One detached Python worker per server socket polls the native API every
0.5 seconds, without launching CLI processes for each poll. It keeps running
after detach and exits when the server stops or replaces its socket. It works
on the endpoint for both local and remote sessions. Apply the helper and Fish
config on each endpoint; an existing session can start it by running
`~/.local/bin/ravy-herdr-auto-title --start` inside a pane. Sessions containing
only explicit command panes need that same command with their `HERDR_SOCKET_PATH`.
Title ownership and the worker log live under
`${XDG_STATE_HOME:-~/.local/state}/ravy/herdr-tab-titles/`, separately per socket,
so restarting the worker preserves both automatic and manual names.

### Persistence and deliberate updates

Detach or client loss leaves live server processes running. A server restart
restores layout with fresh shells; it cannot preserve the old processes.
Automatic agent resume and experimental pane-history persistence are disabled.
Herdr owns layout restoration. No automatic agent or paid-model invocation is added.
Version and agent-manifest background checks are disabled; this is not a claim
that every possible Herdr feature is network-free. Upgrade the pinned version
only after rerunning the real-terminal and SSH tests.

