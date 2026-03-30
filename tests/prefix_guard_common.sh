#!/usr/bin/env bash

guard_lib_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

guard_normalize_root() {
  (
    CDPATH=
    cd -- "$1"
    pwd -P
  )
}

guard_abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$(pwd -P)" "$1" ;;
  esac
}

guard_canon_parent_plus_base() {
  local abs_path dir base prefix

  abs_path=$(guard_abs_path "$1")
  dir=$(dirname -- "$abs_path")
  base=$(basename -- "$abs_path")
  prefix=''

  while [ ! -e "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    prefix="$(basename -- "$dir")/${prefix}${base}"
    base=''
    dir=$(dirname -- "$dir")
  done

  if [ "$dir" = "." ]; then
    dir=$(pwd -P)
  else
    dir=$(CDPATH= cd -- "$dir" && pwd -P)
  fi

  if [ -n "$prefix" ]; then
    printf '%s/%s%s\n' "$dir" "$prefix" "$base"
  else
    printf '%s/%s\n' "$dir" "$base"
  fi
}

guard_canon_access_path() {
  local abs_path

  abs_path=$(guard_abs_path "$1")
  if [ -e "$abs_path" ] || [ -L "$abs_path" ]; then
    if realpath "$abs_path" >/dev/null 2>&1; then
      realpath "$abs_path"
      return 0
    fi
  fi

  guard_canon_parent_plus_base "$abs_path"
}

guard_canon_remove_path() {
  guard_canon_parent_plus_base "$1"
}

guard_assert_path() {
  local root path mode resolved

  root=$(guard_normalize_root "$1")
  path=$2
  mode=${3:-access}

  case "$mode" in
    access) resolved=$(guard_canon_access_path "$path") ;;
    create) resolved=$(guard_canon_parent_plus_base "$path") ;;
    remove) resolved=$(guard_canon_remove_path "$path") ;;
    *)
      printf 'prefix guard: unknown mode %s\n' "$mode" >&2
      return 1
      ;;
  esac

  case "$resolved" in
    "$root"|"$root"/*) ;;
    *)
      printf 'prefix guard blocked %s -> %s outside %s\n' "$path" "$resolved" "$root" >&2
      return 1
      ;;
  esac
}

guard_guess_repo_tmp_root() {
  local repo_root abs_path rel_path segment

  repo_root=$1
  abs_path=$(guard_abs_path "$2")

  case "$abs_path" in
    "$repo_root"/.tmp_*)
      rel_path=${abs_path#"$repo_root"/}
      segment=${rel_path%%/*}
      printf '%s/%s\n' "$repo_root" "$segment"
      ;;
    *)
      return 1
      ;;
  esac
}

guard_assert_repo_tmp_root() {
  local repo_root root

  repo_root=$1
  root=$2

  case "$root" in
    "$repo_root"/.tmp_*) ;;
    *)
      printf 'prefix guard blocked unexpected tmp root %s\n' "$root" >&2
      return 1
      ;;
  esac
}

guard_assert_repo_tmp_path() {
  local root

  root=$(guard_guess_repo_tmp_root "$1" "$2") || {
    printf 'prefix guard blocked path outside repo tmp roots: %s\n' "$2" >&2
    return 1
  }

  guard_assert_path "$root" "$2" "${3:-access}"
}

guard_exec() {
  local root=$1
  shift
  "$guard_lib_dir/prefix_guard_command.sh" "$root" "$@"
}

guard_install_wrappers() {
  local root bin_dir guard_cmd cmd target
  root=$1
  bin_dir=$2
  shift 2

  if [ "$#" -eq 0 ]; then
    set -- rm cp mv ln mkdir touch chmod
  fi

  guard_assert_path "$root" "$bin_dir" create
  /bin/mkdir -p "$bin_dir"
  guard_cmd="$guard_lib_dir/prefix_guard_command.sh"

  for cmd in "$@"; do
    target="$bin_dir/$cmd"
    guard_assert_path "$root" "$target" create
    cat > "$target" <<EOF
#!/usr/bin/env bash
exec "$guard_cmd" "$root" "$cmd" "\$@"
EOF
    /bin/chmod +x "$target"
  done
}
