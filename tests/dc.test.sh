#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DC="$ROOT/bin/dc"
TMPDIR_ROOT=${TMPDIR:-/tmp}
WORK=$(mktemp -d "$TMPDIR_ROOT/ravy-dc-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

SH_MARKER="$WORK/hostile-sh-ran"
DOCKER_MARKER="$WORK/hostile-docker-ran"

cat >"$WORK/sh" <<EOF
#!/bin/sh
: >"$SH_MARKER"
exit 91
EOF
cat >"$WORK/docker" <<EOF
#!/bin/sh
: >"$DOCKER_MARKER"
exit 92
EOF
chmod 700 "$WORK/sh" "$WORK/docker"

IFS= read -r first_line <"$DC"
[ "$first_line" = '#!/bin/sh' ]

PATH="$WORK:/usr/bin:/bin" \
RAVY_DOCKER_COMPOSE_CONFIG="$WORK/absent-compose.yml" \
"$DC" version >/dev/null

[ ! -e "$SH_MARKER" ]
[ ! -e "$DOCKER_MARKER" ]
printf '%s\n' 'DC_HOSTILE_PATH_OK'
