#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=tests/prefix_guard_common.sh
source "$script_dir/prefix_guard_common.sh"

if [ "$#" -lt 2 ]; then
  printf 'usage: %s <root> <command> [args...]\n' "$0" >&2
  exit 64
fi

root=$1
command_name=$2
shift 2

validate_args() {
  local mode=$1
  shift

  for arg in "$@"; do
    guard_assert_path "$root" "$arg" "$mode"
  done
}

validate_generic_command() {
  local command_name=$1
  shift
  local parse_options=1 arg

  case "$command_name" in
    rm)
      for arg in "$@"; do
        if [ "$parse_options" -eq 1 ]; then
          case "$arg" in
            --)
              parse_options=0
              continue
              ;;
            -*)
              continue
              ;;
          esac
        fi
        guard_assert_path "$root" "$arg" remove
      done
      ;;
    mkdir)
      for arg in "$@"; do
        if [ "$parse_options" -eq 1 ]; then
          case "$arg" in
            --)
              parse_options=0
              continue
              ;;
            -*)
              continue
              ;;
          esac
        fi
        guard_assert_path "$root" "$arg" create
      done
      ;;
    chmod)
      local seen_mode=0
      for arg in "$@"; do
        if [ "$parse_options" -eq 1 ]; then
          case "$arg" in
            --)
              parse_options=0
              continue
              ;;
            -*)
              continue
              ;;
          esac
        fi
        if [ "$seen_mode" -eq 0 ]; then
          seen_mode=1
          continue
        fi
        guard_assert_path "$root" "$arg" access
      done
      ;;
    cp|mv|ln|touch)
      for arg in "$@"; do
        if [ "$parse_options" -eq 1 ]; then
          case "$arg" in
            --)
              parse_options=0
              continue
              ;;
            -*)
              continue
              ;;
          esac
        fi
        guard_assert_path "$root" "$arg" access
      done
      ;;
    *)
      printf 'prefix guard does not support command %s\n' "$command_name" >&2
      exit 64
      ;;
  esac
}

validate_generic_command "$command_name" "$@"

command_path="/bin/$command_name"
if [ ! -x "$command_path" ]; then
  command_path="/usr/bin/$command_name"
fi

exec "$command_path" "$@"
