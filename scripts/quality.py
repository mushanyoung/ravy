#!/usr/bin/env python3
"""One fail-closed entrypoint for local and CI quality gates."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STAGES = ("format-check", "lint", "typecheck", "unit", "e2e", "build")


def files() -> list[Path]:
    result = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
    )
    return sorted(
        {
            Path(os.fsdecode(p))
            for p in result.split(b"\0")
            if p and (ROOT / os.fsdecode(p)).is_file()
        }
    )


def groups() -> dict[str, list[str]]:
    result: dict[str, list[str]] = {
        key: [] for key in ("python", "shell", "zsh", "fish", "lua", "toml", "prose")
    }
    for path in files():
        if str(path).startswith("docs/archive/") or path.suffix == ".tmpl":
            continue
        text = path.read_text()
        first = text.splitlines()[0] if text.startswith("#!") else ""
        group = None
        if path.suffix == ".py" or first.endswith("python3"):
            group = "python"
        elif path == Path("bin/chrome-bookmarks"):
            continue  # The shell/Ruby boundary is checked separately below.
        elif first.endswith("zsh"):
            group = "zsh"
        elif path.suffix == ".sh" or first.endswith(("/sh", "env sh", "bash")):
            group = "shell"
        elif path.suffix == ".fish":
            group = "fish"
        elif path.suffix == ".lua":
            group = "lua"
        elif path.suffix == ".toml":
            group = "toml"
        elif path.suffix in (".md", ".json", ".yml", ".yaml"):
            group = "prose"
        if group:
            result[group].append(str(path))
    return result


def run(*argv: str, input: str | None = None, text: bool = True) -> None:
    print("+ " + " ".join(argv), flush=True)
    # All callers supply a fixed argv; no shell evaluation or user HOME mutation.
    subprocess.run(argv, cwd=ROOT, check=True, input=input, text=text)


def format_sources(write: bool) -> None:
    source = groups()
    run("ruff", "format", *([] if write else ["--check"]), *source["python"])
    run("shfmt", "-i", "2", "-ci", "-w" if write else "-d", *source["shell"])
    run("fish_indent", "--write" if write else "--check", *source["fish"])
    run("stylua", *([] if write else ["--check"]), *source["lua"])
    run("taplo", "format", *([] if write else ["--check"]), *source["toml"])
    run(
        "node_modules/.bin/prettier",
        "--write" if write else "--check",
        *source["prose"],
    )
    path = ROOT / "bin/chrome-bookmarks"
    shell, ruby = path.read_text().split("#!/usr/bin/env ruby\n", 1)
    formatted = subprocess.check_output(
        ["shfmt", "-ln", "bash", "-i", "2", "-ci"], input=shell, text=True
    )
    if write:
        path.write_text(formatted + "#!/usr/bin/env ruby\n" + ruby)
    elif shell != formatted:
        raise ValueError("bin/chrome-bookmarks: shell prefix needs make format")


def lint() -> None:
    source = groups()
    run("ruff", "check", *source["python"])
    run("shellcheck", "-x", *source["shell"])
    for path in source["zsh"]:
        run("zsh", "-n", path)
    for path in source["fish"]:
        run("fish", "--no-execute", path)
    shell = (
        (ROOT / "bin/chrome-bookmarks").read_text().split("#!/usr/bin/env ruby\n", 1)[0]
    )
    run("shellcheck", "-s", "bash", "-", input=shell, text=True)
    run("ruby", "-cx", "bin/chrome-bookmarks")
    run("actionlint")
    run(sys.executable, "scripts/check_docs.py")
    run("git", "diff", "--check")


def typecheck() -> None:
    # Extensionless programs are all __main__ to mypy; check independently.
    for path in groups()["python"]:
        run("mypy", "--scripts-are-modules", path)


def e2e() -> None:
    series = ["server", "developer"] if sys.platform == "linux" else ["developer"]
    if sys.platform not in ("linux", "darwin"):
        raise ValueError("E2E requires Linux or macOS")
    failed = False
    for name in series:
        try:
            run(sys.executable, "tests/e2e_herdr.py", "--series", name)
        except subprocess.CalledProcessError:
            failed = True
    if failed:
        raise ValueError("required E2E series failed")


def check(output: Path) -> bool:
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for stage in STAGES:
        started = time.monotonic()
        with (output / f"{stage}.log").open("w") as log:
            process = subprocess.Popen(
                [sys.executable, str(Path(__file__).resolve()), stage],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            assert process.stdout is not None
            for line in process.stdout:
                print(line, end="", flush=True)
                log.write(line)
            status = process.wait()
        results.append(
            {
                "stage": stage,
                "exit_code": status,
                "seconds": round(time.monotonic() - started, 2),
            }
        )
        (output / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    return all(result["exit_code"] == 0 for result in results)


@contextmanager
def isolated_environment() -> Iterator[None]:
    inherited = dict(os.environ)
    with tempfile.TemporaryDirectory(prefix="ravy-check-", dir="/tmp") as temporary:
        home = Path(temporary)
        clean = {
            "HOME": str(home),
            "PATH": inherited["PATH"],
            "TERM": "xterm-256color",
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "XDG_STATE_HOME": str(home / ".local/state"),
            "ZDOTDIR": str(home),
            "BASH_ENV": "/dev/null",
            "ENV": "/dev/null",
            "PYTHONDONTWRITEBYTECODE": "1",
        }
        clean.update(
            {
                key: value
                for key, value in inherited.items()
                if key.startswith("RAVY_TEST_SSHD")
            }
        )
        try:
            os.environ.clear()
            os.environ.update(clean)
            yield
        finally:
            os.environ.clear()
            os.environ.update(inherited)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=(*STAGES, "format", "check", "diagnostic"))
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/check")
    args = parser.parse_args()
    os.chdir(ROOT)
    if args.stage == "check":
        return 0 if check(args.output) else 1
    if args.stage in ("format", "format-check"):
        format_sources(args.stage == "format")
    elif args.stage == "lint":
        lint()
    elif args.stage == "typecheck":
        typecheck()
    elif args.stage == "unit":
        with isolated_environment():
            run("make", "test")
    elif args.stage == "e2e":
        with isolated_environment():
            e2e()
    elif args.stage == "diagnostic":
        with isolated_environment():
            run(sys.executable, "tests/e2e_herdr.py", "--series", "agent-rotation")
    elif args.stage == "build":
        run(sys.executable, "scripts/build.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
