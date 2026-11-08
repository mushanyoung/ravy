"""Render the public production payload into an isolated HOME and validate it."""

import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from pathlib import Path

import json5
from quality import files

ROOT = Path(__file__).resolve().parents[1]


def build(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ravy-build-", dir="/tmp") as temporary:
        root = Path(temporary)
        home = root / "home"
        home.mkdir()
        # Rendering the live checkout could include custom/mise/config.toml.
        # Copy only public Git inputs; never expose the real private repository.
        source = root / "source"
        source.mkdir()
        (source / ".git").mkdir()
        for relative in files():
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        config = root / "chezmoi.toml"
        config.write_text("")
        env = {
            "PATH": os.environ["PATH"],
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "RAVY_PRIVATE_HOME": str(root / "no-private"),
            "RAVY_SKIP_BREW": "1",
        }
        subprocess.run(
            [
                "chezmoi",
                "--source",
                str(source),
                "--destination",
                str(home),
                "--config",
                str(config),
                "--persistent-state",
                str(root / "state.boltdb"),
                "apply",
                "--force",
            ],
            env=env,
            cwd=root,
            check=True,
        )
        paths = sorted(p for p in home.rglob("*") if p.is_file())
        for path in paths:
            relative = path.relative_to(home)
            if path.name == "AGENTS.md" or relative.parts[0] in {
                "docs",
                "tests",
                "scripts",
                "custom",
                "artifacts",
                "dist",
                "node_modules",
                ".venv",
            }:
                raise ValueError(
                    f"repository-only file leaked into payload: {relative}"
                )
            if path.suffix == ".toml":
                tomllib.loads(path.read_text())
            elif path.suffix == ".json":
                # CoC uses JSON with comments, despite its .json filename.
                json5.loads(path.read_text())
            elif path.suffix == ".fish":
                subprocess.run(["fish", "--no-execute", str(path)], env=env, check=True)
        for shell, name in (
            ("bash", ".bashrc"),
            ("bash", ".bash_profile"),
            ("zsh", ".zshrc"),
        ):
            subprocess.run([shell, "-n", str(home / name)], env=env, check=True)
        env["RAVY_NVIM_SKIP_PLUGINS"] = "1"
        subprocess.run(["nvim", "--headless", "+qa"], env=env, cwd=home, check=True)
        payload = output / f"ravy-{sys.platform}.tar.gz"
        with tarfile.open(payload, "w:gz") as archive:
            for path in paths:
                archive.add(path, arcname=str(path.relative_to(home)), recursive=False)
        (output / f"manifest-{sys.platform}.json").write_text(
            json.dumps([str(p.relative_to(home)) for p in paths], indent=2) + "\n"
        )
        print(f"Production render: {len(paths)} files validated; {payload}")


if __name__ == "__main__":
    build(ROOT / "dist")
