#!/usr/bin/env python3
"""Real Herdr/PTY/OpenSSH tests. Never use live sessions or developer credentials.

--series server: headless Linux lifecycle and keyboard contracts.
--series developer: native SSH to a disposable same-OS macOS/Linux dev fixture.
--series agent-rotation: opt-in diagnostic; failure remains a nonzero exit.
Missing prerequisites are errors, never silent skips. No model/agent calls.
"""

import argparse
import errno
import fcntl
import hashlib
import json
import os
import pty
import pwd
import select
import shlex
import shutil
import signal
import socket
import stat
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS: dict[str, str] = {}
SERIES = "server"


def temporary_runtime(prefix):
    # macOS's default TMPDIR can exceed Unix socket limits; a test directory
    # beneath the account home can also expose ancestor mise configuration.
    return tempfile.TemporaryDirectory(prefix=prefix, dir="/tmp")


def isolated_home_env(home):
    return {
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "ZDOTDIR": str(home),
        "BASH_ENV": "/dev/null",
        "ENV": "/dev/null",
    }


def prepare_ssh_home(home, shell):
    """Isolate user startup before ForceCommand; leave system startup intact."""
    home.mkdir(mode=0o700)
    startup = {
        "fish": ".config/fish/config.fish",
        "zsh": ".zshenv",
        "bash": ".bashrc",
        "sh": None,
        "dash": None,
    }
    name = Path(shell).name
    if name not in startup:
        raise ValueError(f"unsupported SSH login shell for isolated tests: {shell}")
    marker = None
    if startup[name]:
        marker = home / "startup.env"
        rc = home / startup[name]
        rc.parent.mkdir(parents=True, exist_ok=True)
        # A real SSH preflight must prove the account shell read the fixture's
        # startup file, with isolation already active, before the launcher runs.
        rc.write_text(
            'printf \'%s\\n\' "$HOME" "$XDG_CONFIG_HOME" "$ZDOTDIR" > '
            + shlex.quote(str(marker))
            + "\n"
        )
    return isolated_home_env(home) | {"PATH": "/usr/bin:/bin"}, marker


def authorized_keys_directory(account_home):
    # StrictModes follows AuthorizedKeysFile ancestors until the passwd home.
    # A private leaf in /tmp still fails because /tmp itself is world-writable.
    home = Path(account_home).resolve(strict=True)
    info = home.stat()
    if (
        not home.is_dir()
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) & 0o022
    ):
        raise ValueError(
            "SSH tests require an owned, non-group/world-writable account home"
        )
    return tempfile.TemporaryDirectory(prefix=".ravy-herdr-keys-", dir=home)


def ssh_config_quote(value):
    if any(char in value for char in "\n\r\0"):
        raise ValueError("invalid SSH configuration value")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def until(fn, timeout=10, message="timed out waiting for verified state"):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        result = fn()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError(message)


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


class Client:
    def __init__(self, argv, env):
        self.master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 140, 0, 0))
        self.process = subprocess.Popen(
            argv,
            env=env,
            stdin=slave,
            stdout=slave,
            stderr=slave,
            start_new_session=True,
            cwd=env["HOME"],
        )
        os.close(slave)
        self.closed = False
        self.output = bytearray()
        self.thread = threading.Thread(target=self.drain, daemon=True)
        self.thread.start()

    def drain(self):
        while not self.closed:
            try:
                ready, _, _ = select.select([self.master], [], [], 0.1)
                if not ready:
                    continue
                data = os.read(self.master, 65536)
                if not data:
                    return
                self.output.extend(data)
                if len(self.output) > 200000:
                    del self.output[:-100000]
                # Minimal xterm responses; input assertions go through real PTY bytes.
                if b"\x1b[6n" in data:
                    os.write(self.master, b"\x1b[1;1R")
                if b"\x1b[c" in data:
                    os.write(self.master, b"\x1b[?1;2c")
                if b"\x1b]11;?" in data:
                    os.write(self.master, b"\x1b]11;rgb:0000/0000/0000\x1b\\")
            except OSError as exc:
                if exc.errno in (errno.EIO, errno.EBADF):
                    return
                raise

    def key(self, data):
        if self.process.poll() is not None:
            raise AssertionError(
                "TUI exited before input: "
                + self.output.decode(errors="replace")[-3000:]
            )
        os.write(self.master, data)

    def prefix(self, key):
        self.key(b"\x00")  # Ctrl+Space in legacy terminal encoding
        time.sleep(0.1)
        self.key(key)

    def close(self):
        stop(self.process)
        self.closed = True
        self.thread.join(timeout=2)
        os.close(self.master)


class Fixture:
    def __init__(self, root):
        self.root = root
        self.home = root / "home"
        self.home.mkdir(parents=True)
        self.config = root / "config.toml"
        self.config.write_bytes((ROOT / "dot_config/herdr/config.toml").read_bytes())
        self.env = isolated_home_env(self.home) | {
            "PATH": os.environ["PATH"],
            "TERM": "xterm-256color",
            "LC_ALL": "en_US.UTF-8" if sys.platform == "darwin" else "C.UTF-8",
            "SHELL": TOOLS["fish"],
            "TMPDIR": str(root),
            "HERDR_CONFIG_PATH": str(self.config),
            "RAVY_PRIVATE_HOME": str(root / "no-private"),
            "RAVY_SKIP_BREW": "1",
        }
        # Real rendered Fish startup, not a hand-written imitation.
        target = self.home / ".config/fish/config.fish"
        target.parent.mkdir(parents=True)
        rendered = subprocess.run(
            [
                TOOLS["chezmoi"],
                "-S",
                str(ROOT),
                "-D",
                str(self.home),
                "cat",
                str(target),
            ],
            env=self.env,
            cwd=self.home,
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        target.write_text(rendered.stdout)
        for name in ("ravy-herdr-tab-10", "ravy-herdr-auto-title"):
            helper = self.home / ".local/bin" / name
            helper.parent.mkdir(parents=True, exist_ok=True)
            helper.write_bytes(
                (ROOT / "dot_local/bin" / ("executable_" + name)).read_bytes()
            )
            helper.chmod(0o700)
        self.server = None
        self.clients = []
        self.log = None

    def raw(self, *args):
        result = subprocess.run(
            [TOOLS["herdr"], *args],
            env=self.env,
            cwd=self.home,
            text=True,
            capture_output=True,
            timeout=10,
        )
        return result

    def api(self, *args):
        result = self.raw(*args)
        if result.returncode:
            raise AssertionError(f"Herdr {args}: {result.stderr}")
        return json.loads(result.stdout)["result"] if result.stdout.strip() else {}

    def start(self):
        self.log = open(self.root / "server.log", "a")
        self.server = subprocess.Popen(
            [TOOLS["herdr"], "server"],
            env=self.env,
            cwd=self.home,
            stdout=self.log,
            stderr=self.log,
        )
        until(lambda: self.raw("api", "snapshot").returncode == 0)

    def snapshot(self):
        return self.api("api", "snapshot")["snapshot"]

    def client(self, *args):
        client = Client([str(ROOT / "bin/cloudtop"), *args], self.env)
        self.clients.append(client)
        return client

    def pane(self):
        return next(p for p in self.snapshot()["panes"] if p["focused"])

    def run(self, pane, command, marker):
        self.api("pane", "run", pane, command)
        self.api("pane", "wait-output", pane, "--match", marker, "--timeout", "8000")

    def close_ssh_master(self):
        # v0.9.5 namespaces shared sockets by config path + target. Stop only
        # this disposable fixture's master; never glob all a user's sockets.
        config = self.home / ".ssh/config"
        if not config.exists():
            return
        prefix = hashlib.sha256(os.fsencode(self.config) + b"\0ravy-e2e").hexdigest()[
            :24
        ]
        directory = Path(
            f"/tmp/hssh-{os.getuid()}"
        )  # Native Herdr location, not our temp root.
        for path in directory.glob(prefix + "-*"):
            if (
                path.is_symlink()
                or path.stat().st_uid != os.getuid()
                or not path.is_socket()
            ):
                raise AssertionError("unsafe fixture control socket")
            result = subprocess.run(
                ["ssh", "-F", str(config), "-S", str(path), "-O", "exit", "ravy-e2e"],
                env=self.env,
                capture_output=True,
                timeout=5,
            )
            if result.returncode != 0 and path.exists():
                raise AssertionError("could not stop fixture SSH master")
            until(lambda: not path.exists())

    def close(self):
        for client in self.clients:
            client.close()
        self.close_ssh_master()
        self.raw("server", "stop")
        until(
            lambda: self.raw("api", "snapshot").returncode != 0,
            message="fixture server did not stop",
        )
        # Detached title workers must release their locks when this server ends.
        locks = list(
            (self.home / ".local/state/ravy/herdr-tab-titles").glob("*/worker.lock")
        )

        def titles_stopped():
            for path in locks:
                with path.open() as lock:
                    try:
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    except BlockingIOError:
                        return False
            return True

        until(titles_stopped, message="title worker outlived its Herdr server")
        for path in locks:
            log = path.with_name("worker.log").read_text()
            if log:
                raise AssertionError("title worker failed: " + log)
        if self.server:
            self.server.wait(timeout=5)
        if self.log:
            self.log.close()
        # Configuration warnings are test failures, not successful fallback defaults.
        text = "\n".join(p.read_text(errors="replace") for p in self.root.glob("*.log"))
        if "config diagnostic" in text or "failed to parse config" in text.lower():
            raise AssertionError("Herdr rejected configuration: " + text[-4000:])


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.temp = temporary_runtime("he-")
        self.addCleanup(self.temp.cleanup)
        self.fx = Fixture(Path(self.temp.name))
        self.addCleanup(self.fx.close)
        self.fx.start()

    def test_automatic_tab_titles(self):
        fx = self.fx
        fx.api("workspace", "create", "--cwd", str(fx.home))
        client = fx.client()
        until(lambda: b"\x1b[" in client.output)
        pane = fx.pane()["pane_id"]
        tab = fx.pane()["tab_id"]

        def label(tab_id):
            return next(
                t["label"] for t in fx.snapshot()["tabs"] if t["tab_id"] == tab_id
            )

        until(lambda: label(tab) == "1 ~")
        project = fx.home / "parent" / "leaf with spaces"
        project.mkdir(parents=True)
        fx.run(
            pane, "cd " + shlex.quote(str(project)) + "; echo DIR_READY", "DIR_READY"
        )
        until(lambda: label(tab) == "1 leaf with spaces/")
        fx.run(pane, "sleep 30 &; echo BG_READY", "BG_READY")
        time.sleep(1)
        self.assertEqual(label(tab), "1 leaf with spaces/")
        fx.api("pane", "run", pane, "sleep 30")
        until(lambda: label(tab) == "1 ▶ sleep")
        fx.api("pane", "send-keys", pane, "ctrl+c")
        until(lambda: label(tab) == "1 leaf with spaces/")
        fx.api(
            "pane",
            "split",
            pane,
            "--direction",
            "right",
            "--cwd",
            str(fx.home),
            "--focus",
        )
        until(lambda: label(tab) == "1 ~")
        fx.api("pane", "focus", "--direction", "left")
        until(lambda: label(tab) == "1 leaf with spaces/")
        # Manual titles retain their suffix when moving/closing other tabs.
        fx.api("tab", "rename", tab, "review")
        until(lambda: label(tab) == "1 review")
        client.prefix(b"c")
        until(lambda: len(fx.snapshot()["tabs"]) == 2)
        second = fx.pane()["tab_id"]
        until(lambda: label(second) == "2 ~")
        client.key(b"\x1bu")
        until(lambda: label(second) == "1 ~" and label(tab) == "2 review")
        fx.api("tab", "close", tab)
        until(lambda: len(fx.snapshot()["tabs"]) == 1)
        self.assertEqual(label(second), "1 ~")
        # Duplicate Fish starts must not create a second worker. Restarting it
        # also must not misclassify its persisted automatic title as manual.
        locks = list(
            (fx.home / ".local/state/ravy/herdr-tab-titles").glob("*/worker.lock")
        )
        self.assertEqual(len(locks), 1)
        pid = json.loads(locks[0].read_text())["pid"]
        fx.api("pane", "split", "--direction", "right", "--focus")
        time.sleep(1)
        self.assertEqual(json.loads(locks[0].read_text())["pid"], pid)
        os.kill(pid, signal.SIGTERM)
        time.sleep(0.1)
        fx.api(
            "pane",
            "run",
            fx.pane()["pane_id"],
            '"$HOME/.local/bin/ravy-herdr-auto-title" --start; sleep 30',
        )
        until(lambda: label(second) == "1 ▶ sleep")
        self.assertNotEqual(json.loads(locks[0].read_text())["pid"], pid)

    def test_keyboard_cwd_splits_tabs_and_detach(self):
        fx = self.fx
        project = fx.home / "project with spaces"
        project.mkdir()
        fx.api("workspace", "create", "--cwd", str(project))
        client = fx.client()
        until(lambda: b"\x1b[" in client.output)
        time.sleep(1)
        client.prefix(b"n")
        until(lambda: len(fx.snapshot()["tabs"]) == 2)
        self.assertEqual(Path(fx.pane()["cwd"]).resolve(), project.resolve())
        client.prefix(b"c")
        until(lambda: len(fx.snapshot()["tabs"]) == 3)
        self.assertEqual(Path(fx.pane()["cwd"]).resolve(), fx.home.resolve())
        client.prefix(b"\\")
        until(lambda: len(fx.snapshot()["panes"]) == 4)
        right = fx.pane()["pane_id"]
        client.prefix(b"h")
        until(lambda: fx.pane()["pane_id"] != right)
        client.prefix(b"l")
        until(lambda: fx.pane()["pane_id"] == right)
        client.prefix(b"-")
        until(lambda: len(fx.snapshot()["panes"]) == 5)
        for _ in range(7):
            fx.api("tab", "create")
        tabs = fx.snapshot()["tabs"]
        tenth = next(t["tab_id"] for t in tabs if t["number"] == 10)
        client.key(b"\x1b1")
        until(
            lambda: next(t for t in fx.snapshot()["tabs"] if t["focused"])["number"]
            == 1
        )
        client.key(b"\x1b0")
        until(
            lambda: next(t for t in fx.snapshot()["tabs"] if t["focused"])["tab_id"]
            == tenth
        )
        client.prefix(b"d")
        self.assertEqual(client.process.wait(timeout=5), 0)
        self.assertEqual(len(fx.snapshot()["tabs"]), 10)
        reconnect = fx.client()
        time.sleep(1)
        self.assertIsNone(reconnect.process.poll())
        self.assertEqual(len(fx.snapshot()["tabs"]), 10)

    def test_real_neovim_input_and_detach(self):
        fx = self.fx
        fx.api("workspace", "create", "--cwd", str(fx.home))
        client = fx.client()
        time.sleep(1)
        output = fx.root / "editor.txt"
        ready = fx.root / "editor-ready"
        script = fx.root / "ready.vim"
        script.write_text(f"call writefile(['ready'], '{ready}')\n")
        fx.api(
            "pane",
            "run",
            fx.pane()["pane_id"],
            f"{shlex.quote(TOOLS['nvim'])} -u NONE -n -S {shlex.quote(str(script))} {shlex.quote(str(output))}",
        )
        until(ready.exists)
        client.prefix(b"d")
        self.assertEqual(client.process.wait(timeout=5), 0)
        reconnect = fx.client()
        time.sleep(1)
        reconnect.key("i中文 input survives detach".encode())
        time.sleep(0.1)
        reconnect.key(b"\x1b:wq\r")
        until(output.exists)
        self.assertEqual(output.read_text(), "中文 input survives detach\n")

    def test_headless_process_survives_client_loss_and_restart_restores_layout(self):
        fx = self.fx
        created = fx.api("workspace", "create", "--cwd", str(fx.home))
        pane = created["root_pane"]["pane_id"]
        marker = fx.root / "counter"
        fx.run(
            pane,
            f"sh -c 'while :; do date +%s > {shlex.quote(str(marker))}; sleep 1; done'",
            "while",
        )
        until(marker.exists)
        client = fx.client()
        time.sleep(1)
        stop(client.process)  # Lost client, not a clean detach.
        before = marker.stat().st_mtime_ns
        until(lambda: marker.stat().st_mtime_ns > before)
        self.assertEqual(len(fx.snapshot()["panes"]), 1)
        fx.api("server", "stop")
        assert fx.server is not None and fx.log is not None
        fx.server.wait(timeout=5)
        fx.log.close()
        fx.start()
        until(lambda: len(fx.snapshot()["panes"]) == 1)
        self.assertEqual(Path(fx.pane()["cwd"]).resolve(), fx.home.resolve())
        until(
            lambda: fx.snapshot()["tabs"][0]["label"] == "1 ~",
            message="restored shell did not restart automatic titles",
        )
        before = marker.stat().st_mtime_ns
        time.sleep(1.2)
        self.assertEqual(
            marker.stat().st_mtime_ns, before, "restart must not resurrect commands"
        )


class SSHTests(unittest.TestCase):
    def setUp(self):
        self.temp = temporary_runtime("hd-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = Fixture(self.root / "r")
        self.local = Fixture(self.root / "l")
        self.addCleanup(self.remote.close)
        self.addCleanup(self.local.close)
        self.setup_ssh()

    def setup_ssh(self):
        root = self.root
        account = pwd.getpwuid(os.getuid())
        env = {"HOME": str(root), "PATH": "/usr/bin:/bin"}
        for name in ("host", "identity"):
            subprocess.run(
                ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(root / name)],
                env=env,
                check=True,
                timeout=5,
            )
        keys = authorized_keys_directory(account.pw_dir)
        self.addCleanup(keys.cleanup)
        authorized_keys = Path(keys.name) / "authorized_keys"
        authorized_keys.write_bytes((root / "identity.pub").read_bytes())
        authorized_keys.chmod(0o600)
        bootstrap_env, startup_marker = prepare_ssh_home(root / "b", account.pw_shell)
        # sshd starts the account shell BEFORE ForceCommand. SetEnv below must
        # isolate that shell; this launcher then selects the rendered Ravy home.
        launcher = root / "remote.py"
        launcher.write_text(
            "#!"
            + sys.executable
            + "\nimport os\n"
            + "expected = "
            + repr(bootstrap_env)
            + "\n"
            + "if any(os.environ.get(k) != v for k,v in expected.items() if k != 'PATH'):\n"
            + " raise SystemExit('SSH startup environment escaped fixture')\n"
            + "env = "
            + repr(self.remote.env)
            + "\n"
            + "for k in ('SSH_AUTH_SOCK','SSH_CONNECTION','SSH_TTY','TERM'):\n"
            + " if k in os.environ: env[k] = os.environ[k]\n"
            + "os.chdir(env['HOME'])\n"
            + "os.execve('/bin/sh', ['sh','-c',os.environ.get('SSH_ORIGINAL_COMMAND','exit 2')],env)\n"
        )
        launcher.chmod(0o700)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        config = root / "sshd.conf"
        text = f"""ListenAddress 127.0.0.1
Port {port}
HostKey {root}/host
PidFile {root}/sshd.pid
AuthorizedKeysFile {ssh_config_quote(str(authorized_keys))}
StrictModes yes
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
PermitUserEnvironment no
PermitUserRC no
AllowAgentForwarding yes
AllowUsers {account.pw_name}
ForceCommand {launcher}
"""
        text += (
            "SetEnv "
            + " ".join(
                ssh_config_quote(f"{key}={value}")
                for key, value in bootstrap_env.items()
            )
            + "\n"
        )
        # Optional relocated OpenSSH package support for rootless Linux testing.
        for option, var in (
            ("SshdSessionPath", "RAVY_TEST_SSHD_SESSION"),
            ("SshdAuthPath", "RAVY_TEST_SSHD_AUTH"),
        ):
            if os.environ.get(var):
                text += f"{option} {os.environ[var]}\n"
        if os.environ.get("RAVY_TEST_SSHD_LIB_DIR"):
            env["LD_LIBRARY_PATH"] = os.environ["RAVY_TEST_SSHD_LIB_DIR"]
        config.write_text(text)
        log = open(root / "sshd.log", "w")
        self.addCleanup(log.close)
        daemon = subprocess.Popen(
            [TOOLS["sshd"], "-D", "-e", "-f", str(config)],
            env=env,
            stdout=log,
            stderr=log,
        )
        self.addCleanup(stop, daemon)
        time.sleep(0.3)
        self.assertIsNone(daemon.poll(), (root / "sshd.log").read_text())
        sshdir = self.local.home / ".ssh"
        sshdir.mkdir(mode=0o700)
        public_host = (root / "host.pub").read_text().split()
        known = sshdir / "known_hosts"
        known.write_text(f"[127.0.0.1]:{port} {public_host[0]} {public_host[1]}\n")
        (sshdir / "config").write_text(f"""Host ravy-e2e
  HostName 127.0.0.1
  Port {port}
  User {account.pw_name}
  IdentityFile {root}/identity
  IdentitiesOnly yes
  ForwardAgent yes
  StrictHostKeyChecking yes
  UserKnownHostsFile {known}
  BatchMode yes
""")
        # A foreground ssh-agent owns only a generated, short-lived test key.
        self.start_agent("identity", "agent")
        probe = subprocess.run(
            [
                "ssh",
                "-F",
                str(sshdir / "config"),
                "-o",
                "ControlMaster=no",
                "-o",
                "ControlPath=none",
                "ravy-e2e",
                "true",
            ],
            env=self.local.env,
            cwd=self.local.home,
            stdin=subprocess.DEVNULL,
            text=True,
            capture_output=True,
            timeout=10,
        )
        self.assertEqual(
            probe.returncode, 0, probe.stderr + (root / "sshd.log").read_text()
        )
        if startup_marker:
            self.assertEqual(
                startup_marker.read_text().splitlines(),
                [bootstrap_env[key] for key in ("HOME", "XDG_CONFIG_HOME", "ZDOTDIR")],
            )

    def start_agent(self, identity, name):
        root = self.root
        env = {"HOME": str(root), "PATH": "/usr/bin:/bin"}
        self.agent_sock = root / name
        agent = subprocess.Popen(
            ["ssh-agent", "-D", "-a", str(self.agent_sock)],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.agent = agent
        self.addCleanup(stop, agent)
        until(self.agent_sock.is_socket)
        self.local.env["SSH_AUTH_SOCK"] = str(self.agent_sock)
        subprocess.run(
            ["ssh-add", str(root / identity)],
            env=self.local.env,
            check=True,
            capture_output=True,
            timeout=5,
        )


class AgentReattachTests(SSHTests):
    def exercise_reattach(self, rotate, fresh_connection):
        remote, local = self.remote, self.local
        client = local.client("ravy-e2e")
        until(lambda: remote.raw("api", "snapshot").returncode == 0)
        time.sleep(2)
        self.assertIsNone(
            client.process.poll(), client.output.decode(errors="replace")[-3000:]
        )
        client.prefix(b"n")
        until(lambda: len(remote.snapshot()["tabs"]) == 2)
        pane = remote.pane()["pane_id"]
        # Native remote attach supplies the stable address to panes created after attach.
        signature = remote.root / "signed"
        public = self.root / "identity.pub"
        payload = self.root / "payload"
        payload.write_text("synthetic E2E payload\n")
        command = (
            f"ssh-add -T {shlex.quote(str(public))}; and "
            f"ssh-keygen -Y sign -n ravy-e2e -f {shlex.quote(str(public))} "
            f"{shlex.quote(str(payload))}; and touch {shlex.quote(str(signature))}"
        )
        remote.api("pane", "run", pane, command)
        until(signature.exists)
        # Verify an actual agent-backed signature, not merely socket presence.
        allowed = self.root / "allowed"
        fields = public.read_text().split()
        allowed.write_text(f"test {fields[0]} {fields[1]}\n")
        with payload.open("rb") as data:
            verified = subprocess.run(
                [
                    "ssh-keygen",
                    "-Y",
                    "verify",
                    "-f",
                    str(allowed),
                    "-I",
                    "test",
                    "-n",
                    "ravy-e2e",
                    "-s",
                    str(payload) + ".sig",
                ],
                stdin=data,
                capture_output=True,
                timeout=5,
            )
        self.assertEqual(verified.returncode, 0)
        stop(client.process)
        if rotate:
            stop(self.agent)
            # A fresh agent holds a different key. A stale socket cannot pass this.
            subprocess.run(
                [
                    "ssh-keygen",
                    "-q",
                    "-t",
                    "ed25519",
                    "-N",
                    "",
                    "-f",
                    str(self.root / "identity2"),
                ],
                env=local.env,
                check=True,
                timeout=5,
            )
            self.start_agent("identity2", "agent2")
            public = self.root / "identity2.pub"
        if fresh_connection:
            # Explicit test condition and diagnostic control, never production repair.
            local.close_ssh_master()
        reconnect = local.client("ravy-e2e")
        time.sleep(2)
        self.assertIsNone(reconnect.process.poll())
        marker = remote.root / "after-reconnect"
        remote.api(
            "pane",
            "run",
            pane,
            f"ssh-add -T {shlex.quote(str(public))}; and touch {shlex.quote(str(marker))}",
        )
        until(
            marker.exists,
            message=f"SSH signing failed after reconnect: rotated_agent={rotate}, fresh_transport={fresh_connection}",
        )
        reconnect.prefix(b"n")
        until(lambda: len(remote.snapshot()["tabs"]) == 3)
        marker2 = remote.root / "new-pane"
        remote.api(
            "pane",
            "run",
            remote.pane()["pane_id"],
            f"ssh-add -T {shlex.quote(str(public))}; and touch {shlex.quote(str(marker2))}",
        )
        until(marker2.exists)
        self.assertFalse((remote.home / ".ssh/ssh_auth_sock").exists())
        reconnect.prefix(b"d")
        self.assertEqual(reconnect.process.wait(timeout=5), 0)
        self.assertEqual(len(remote.snapshot()["tabs"]), 3)


class DeveloperTests(AgentReattachTests):
    def test_remote_custom_home_tab_and_tab_ten(self):
        remote, local = self.remote, self.local
        client = local.client("ravy-e2e")
        until(lambda: remote.raw("api", "snapshot").returncode == 0)
        until(lambda: remote.snapshot()["tabs"][0]["label"] == "1 ~")
        project = remote.home / "project with spaces"
        project.mkdir()
        remote.api(
            "pane", "run", remote.pane()["pane_id"], "cd " + shlex.quote(str(project))
        )
        # macOS reports process cwd through /private/tmp even when launched
        # through /tmp. Compare directories, not the symlink spelling.
        until(lambda: Path(remote.pane()["cwd"]).resolve() == project.resolve())
        until(lambda: remote.snapshot()["tabs"][0]["label"] == "1 project with spaces/")
        client.prefix(b"n")
        until(lambda: len(remote.snapshot()["tabs"]) == 2)
        self.assertEqual(Path(remote.pane()["cwd"]).resolve(), project.resolve())
        client.prefix(b"c")
        until(
            lambda: len(remote.snapshot()["tabs"]) == 3,
            message="remote home-tab custom command did not run",
        )
        self.assertEqual(Path(remote.pane()["cwd"]).resolve(), remote.home.resolve())
        self.assertNotEqual(Path(remote.pane()["cwd"]).resolve(), local.home.resolve())
        until(lambda: remote.snapshot()["tabs"][2]["label"] == "3 ~")
        for _ in range(7):
            remote.api("tab", "create")
        client.key(b"\x1b1")
        until(
            lambda: next(t for t in remote.snapshot()["tabs"] if t["focused"])["number"]
            == 1
        )
        client.key(b"\x1b0")
        until(
            lambda: next(t for t in remote.snapshot()["tabs"] if t["focused"])["number"]
            == 10,
            message="remote tab-10 custom command did not run",
        )
        remote.api("tab", "close", remote.snapshot()["tabs"][0]["tab_id"])
        remote.api("tab", "create")
        tenth = remote.snapshot()["tabs"][9]["tab_id"]
        until(lambda: remote.snapshot()["tabs"][9]["label"] == "10 ~")
        client.key(b"\x1b0")
        until(
            lambda: remote.pane()["tab_id"] == tenth,
            message="Alt+0 must follow display order after closing and creating tabs",
        )
        remote.api("pane", "run", remote.pane()["pane_id"], "sleep 30")
        until(lambda: remote.snapshot()["tabs"][9]["label"] == "10 ▶ sleep")
        client.prefix(b"d")
        self.assertEqual(client.process.wait(timeout=5), 0)

    def test_native_remote_keys_forwarding_and_reattach(self):
        self.exercise_reattach(rotate=False, fresh_connection=False)

    def test_replaced_agent_with_fresh_transport(self):
        self.exercise_reattach(rotate=True, fresh_connection=True)


class AgentRotationDiagnostics(AgentReattachTests):
    def test_replaced_agent_with_reused_transport(self):
        # Accepted operational limitation, retained as a strict opt-in diagnostic.
        # No xfail/skip, automatic master reset or weaker signing assertion.
        self.exercise_reattach(rotate=True, fresh_connection=False)


class LinuxServerRemoteTests(SSHTests):
    def test_native_server_survives_broken_ssh_transport(self):
        remote, local = self.remote, self.local
        client = local.client("ravy-e2e")
        until(lambda: remote.raw("api", "snapshot").returncode == 0)
        time.sleep(1)
        pane = remote.pane()["pane_id"]
        marker = remote.root / "heartbeat"
        remote.api(
            "pane",
            "run",
            pane,
            f"sh -c 'while :; do date +%s > {shlex.quote(str(marker))}; sleep 1; done'",
        )
        until(marker.exists)
        # Kill only ssh processes descended from this fixture's exact client.
        # This breaks a real SSH transport; no simulated network or fake server.
        tree = subprocess.check_output(["ps", "-eo", "pid=,ppid=,comm="], text=True)
        rows = [line.split(None, 2) for line in tree.splitlines()]
        descendants = {client.process.pid}
        while True:
            added = {int(pid) for pid, parent, _ in rows if int(parent) in descendants}
            if added <= descendants:
                break
            descendants |= added
        targets = [
            int(pid)
            for pid, _, name in rows
            if int(pid) in descendants and Path(name).name == "ssh"
        ]
        self.assertTrue(targets, "must break an actual fixture SSH transport")
        before = marker.stat().st_mtime_ns
        for pid in targets:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        until(lambda: marker.stat().st_mtime_ns > before)
        self.assertEqual(remote.pane()["pane_id"], pane)
        stop(client.process)
        reconnect = local.client("ravy-e2e")
        time.sleep(1)
        self.assertIsNone(reconnect.process.poll())
        reconnect.prefix(b"n")
        until(lambda: len(remote.snapshot()["tabs"]) == 2)
        self.assertIn(pane, [p["pane_id"] for p in remote.snapshot()["panes"]])
        reconnect.prefix(b"d")
        self.assertEqual(reconnect.process.wait(timeout=5), 0)
        before = marker.stat().st_mtime_ns
        until(lambda: marker.stat().st_mtime_ns > before)


def build_suite(series):
    cases = {
        "server": (ServerTests, LinuxServerRemoteTests),
        "developer": (DeveloperTests,),
        "agent-rotation": (AgentRotationDiagnostics,),
    }
    if series not in cases:
        raise ValueError(f"unknown E2E series: {series}")
    return unittest.TestSuite(
        unittest.defaultTestLoader.loadTestsFromTestCase(case) for case in cases[series]
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--series", choices=("server", "developer", "agent-rotation"), required=True
    )
    args = parser.parse_args()
    SERIES = args.series
    if SERIES == "server" and sys.platform != "linux":
        parser.error("the Linux server suite requires a real Linux host")
    required = ["herdr", "fish", "chezmoi", "sshd"] + (
        ["nvim"] if SERIES == "server" else []
    )
    for name in required:
        candidate = os.environ.get("RAVY_TEST_SSHD") if name == "sshd" else None
        candidate = (
            candidate
            or shutil.which(name)
            or ("/usr/sbin/sshd" if name == "sshd" else None)
        )
        if not candidate or not Path(candidate).is_file():
            parser.error(f"required real executable missing: {name}")
        TOOLS[name] = candidate
    version = subprocess.run(
        [TOOLS["herdr"], "--version"], capture_output=True, text=True, timeout=5
    )
    if version.returncode or version.stdout.strip() != "herdr 0.9.5":
        parser.error(
            "this version-bound suite requires Herdr 0.9.5; audit fixtures before upgrading"
        )
    result = unittest.TextTestRunner(verbosity=2).run(build_suite(SERIES))
    sys.exit(not result.wasSuccessful())
