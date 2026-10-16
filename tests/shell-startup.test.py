#!/usr/bin/env python3
"""Exercise rendered shell startup with portable paths and changed installations."""

from pathlib import Path
import shutil
import subprocess
import tempfile


REPO = Path(__file__).resolve().parent.parent
CHEZMOI = shutil.which("chezmoi")


def run(args, env):
    return subprocess.run(args, env=env, check=True, capture_output=True, text=True).stdout


with tempfile.TemporaryDirectory(prefix=".tmp_startup_", dir=REPO) as temporary:
    root = Path(temporary)
    home = root / "home"
    source = root / "source with 'quotes' $literal\\\\slashes"
    templates = source / ".chezmoitemplates"
    templates.mkdir(parents=True)
    home.mkdir()
    for name in ("ravy_fish_common", "ravy_sh_common", "ravy_env_common",
                 "ravy_homebrew_common", "ravy_shell_quote"):
        shutil.copyfile(REPO / ".chezmoitemplates" / f"{name}.tmpl", templates / f"{name}.tmpl")
    config = root / "chezmoi.toml"
    config.touch()
    bin_dir = root / "discovery-bin"
    bin_dir.mkdir()
    prefix = root / "brew prefix 'quoted' [x] * $literal\\\\slashes"
    for suffix in ("bin", "sbin", "share/man", "share/info"):
        (prefix / suffix).mkdir(parents=True)
    repository = root / "separate repository"
    repository.mkdir()
    cellar = root / "separate cellar"
    cellar.mkdir()
    shims = root / "custom shims"
    shims.mkdir()
    log = root / "brew.log"
    chezmoi_log = root / "chezmoi.log"
    mise_log = root / "mise.log"
    env = {
        "HOME": str(home), "PATH": f"{bin_dir}:/usr/bin:/bin",
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "RAVY_HOST": "test", "RAVY_OS": "test",
        "RAVY_PRIVATE_HOME": str(home / "missing-private"),
        "TEST_PREFIX": str(prefix), "TEST_CELLAR": str(cellar),
        "TEST_REPOSITORY": str(repository), "TEST_BREW_LOG": str(log),
        "TEST_CHEZMOI_LOG": str(chezmoi_log), "TEST_SOURCE": str(source),
        "TEST_MISE_LOG": str(mise_log), "MISE_SHIMS_DIR": str(shims),
        # Stale inherited metadata must not override the detected executable.
        "HOMEBREW_PREFIX": str(home / "stale"), "TERM": "xterm-256color",
    }

    def executable(path, text):
        assert path.is_relative_to(root)
        path.write_text("#!/bin/sh\n" + text)
        path.chmod(0o755)

    executable(bin_dir / "brew", '''printf '%s\n' "$*" >> "$TEST_BREW_LOG"
case "$1" in
  --prefix) printf '%s\n' "$TEST_PREFIX" ;;
  --cellar) printf '%s\n' "$TEST_CELLAR" ;;
  --repository) printf '%s\n' "$TEST_REPOSITORY" ;;
  *) exit 1 ;;
esac
''')
    executable(bin_dir / "chezmoi", '''printf '%s\n' "$*" >> "$TEST_CHEZMOI_LOG"
printf '%s\n' "$TEST_SOURCE"
''')
    executable(bin_dir / "mise", '''printf '%s\n' "$*" >> "$TEST_MISE_LOG"
if [ "$*" = 'activate fish --shims' ]; then
  printf '%s\n' 'set -gx PATH "$MISE_SHIMS_DIR" $PATH'
elif [ "$*" = 'activate fish' ]; then
  printf '%s\n' 'set -gx TEST_INTERACTIVE_MISE 1'
else
  exit 1
fi
''')

    for shell in ("bash", "zsh", "fish"):
        binary = shutil.which(shell)
        if not binary:
            print(f"SKIP {shell}: not installed")
            continue
        template = "ravy_fish_common.tmpl" if shell == "fish" else "ravy_sh_common.tmpl"
        expression = '{{ template "' + template + '" (dict "chezmoi" .chezmoi "shell" "' + shell + '") }}'
        rendered = root / f"startup.{shell}"
        rendered.write_text(run([CHEZMOI, "-S", str(source), "-D", str(home), "-c", str(config),
                                 "execute-template", expression], env))
        shell_env = {**env, "TEST_CONFIG": str(rendered)}
        if shell == "fish":
            flags = ["--no-config"]
            probe = '''source "$TEST_CONFIG"; source "$TEST_CONFIG"
printf '%s\n' "$RAVY_HOME" "$HOMEBREW_PREFIX" "$HOMEBREW_CELLAR" "$HOMEBREW_REPOSITORY" (string join : -- $MANPATH) (string join : -- $INFOPATH) (string join : -- $PATH)
'''
        else:
            flags = ["--noprofile", "--norc"] if shell == "bash" else ["-f"]
            probe = '''source "$TEST_CONFIG"; source "$TEST_CONFIG"
printf '%s\n' "$RAVY_HOME" "$HOMEBREW_PREFIX" "$HOMEBREW_CELLAR" "$HOMEBREW_REPOSITORY" "$MANPATH" "$INFOPATH" "$PATH"
'''

        def check(probe_env, expected_source, expected_prefix):
            lines = run([binary, *flags, "-c", probe], probe_env).splitlines()
            assert lines[:4] == [str(expected_source), str(expected_prefix), str(cellar), str(repository)], (shell, lines)
            for value, suffix in zip(lines[4:6], ("share/man", "share/info")):
                assert value.split(":").count(str(expected_prefix / suffix)) == 1, (shell, value)
                assert "" in value.split(":"), (shell, "system search directories lost", value)
            assert lines[6].split(":").count(str(expected_prefix / "bin")) == 1, (shell, lines[6])
            return lines

        log.write_text("")
        chezmoi_log.write_text("")
        mise_log.write_text("")
        lines = check(shell_env, source, prefix)
        assert not log.read_text(), f"{shell}: cached startup should not execute brew"
        assert not chezmoi_log.read_text(), f"{shell}: cached startup should not execute chezmoi"
        if shell == "fish":
            assert mise_log.read_text().splitlines() == ["activate fish --shims"] * 2
            assert str(shims) in lines[6].split(":"), "noninteractive fish must retain configured tools"
            mise_log.write_text("")
            run([binary, *flags, "-i", "-c", 'source "$TEST_CONFIG"; test "$TEST_INTERACTIVE_MISE" = 1'], shell_env)
            assert mise_log.read_text().splitlines() == ["activate fish"]

        # Explicit overrides need not exist yet and must remain untouched.
        override = home / "chosen checkout"
        check({**shell_env, "RAVY_HOME": str(override)}, override, prefix)

        # A checkout moved after rendering must resolve its new location once.
        moved = root / "moved checkout"
        source.rename(moved)
        try:
            chezmoi_log.write_text("")
            check({**shell_env, "TEST_SOURCE": str(moved)}, moved, prefix)
            assert chezmoi_log.read_text().splitlines() == ["source-path"], shell
        finally:
            moved.rename(source)

        # A different Brew executable must invalidate the rendered metadata.
        other_bin = root / f"other-bin-{shell}"
        other_bin.mkdir()
        shutil.copyfile(bin_dir / "brew", other_bin / "brew")
        (other_bin / "brew").chmod(0o755)
        other_prefix = root / "relocated brew"
        (other_prefix / "bin").mkdir(parents=True, exist_ok=True)
        log.write_text("")
        check({**shell_env, "PATH": f"{other_bin}:{env['PATH']}", "TEST_PREFIX": str(other_prefix)}, source, other_prefix)
        assert "--repository" in log.read_text().splitlines(), shell
        print(f"PASS {shell}: derived paths, quoting, startup fast path, overrides and relocation")

    # When installed, exercise the actual prompt integrations, including their
    # hook composition. A successful query proves that changing directory was
    # recorded after Starship initialized.
    zoxide = shutil.which("zoxide")
    starship = shutil.which("starship")
    if zoxide and starship:
        native_bin = root / "native-bin"
        native_bin.mkdir()
        (native_bin / "zoxide").symlink_to(zoxide)
        (native_bin / "starship").symlink_to(starship)
        (home / ".config").mkdir(exist_ok=True)
        shutil.copyfile(REPO / "dot_config/starship.toml", home / ".config/starship.toml")
        native_env = {**env, "PATH": f"{native_bin}:/usr/bin:/bin", "RAVY_SKIP_BREW": "1", "COLUMNS": "80"}
        for shell in ("bash", "zsh"):
            binary = shutil.which(shell)
            if not binary:
                continue
            rc = home / f".{shell}rc"
            rc.write_text(run([CHEZMOI, "-S", str(REPO), "-D", str(home), "-c", str(config), "cat", str(rc)], native_env))
            visited = home / f"visited-{shell}"
            visited.mkdir()
            probe_env = {**native_env, "TEST_VISITED": str(visited), "TEST_CONFIG": str(rc)}
            if shell == "bash":
                command = [binary, "--noprofile", "--rcfile", str(rc), "-ic",
                           'cd "$TEST_VISITED"; eval "$PROMPT_COMMAND"; zoxide query visited-bash']
            else:
                command = [binary, "-f", "-ic", 'source "$TEST_CONFIG"; typeset -f prompt_starship_precmd >/dev/null || exit 1; cd "$TEST_VISITED"; zoxide query visited-zsh']
            assert run(command, probe_env).strip() == str(visited), shell
            print(f"PASS {shell}: zoxide records visits after Starship initializes")
    else:
        print("SKIP native prompt integration: zoxide or starship not installed")
