#!/usr/bin/env sh

_ravy_config_home="${XDG_CONFIG_HOME:-$HOME/.config}/ravy"
_ravy_secrets_tsv="$_ravy_config_home/secrets.tsv"
_ravy_tab="$(printf '\t')"
_ravy_cr="$(printf '\r')"

_ravy_trim_tsv_key() {
  _ravy_field=${1%"$_ravy_cr"}
  while :; do
    case "$_ravy_field" in
      ' '*)
        _ravy_field=${_ravy_field# }
        ;;
      "$_ravy_tab"*)
        _ravy_field=${_ravy_field#"$_ravy_tab"}
        ;;
      *)
        break
        ;;
    esac
  done
  while :; do
    case "$_ravy_field" in
      *' ')
        _ravy_field=${_ravy_field% }
        ;;
      *"$_ravy_tab")
        _ravy_field=${_ravy_field%"$_ravy_tab"}
        ;;
      *)
        break
        ;;
    esac
  done
  printf '%s' "$_ravy_field"
}

_ravy_trim_tsv_value() {
  _ravy_field=${1%"$_ravy_cr"}
  while :; do
    case "$_ravy_field" in
      ' '*)
        _ravy_field=${_ravy_field# }
        ;;
      "$_ravy_tab"*)
        _ravy_field=${_ravy_field#"$_ravy_tab"}
        ;;
      *)
        break
        ;;
    esac
  done
  printf '%s' "$_ravy_field"
}

_ravy_expand_tsv_home() {
  _ravy_field=$1
  case "$_ravy_field" in
    '~'|'~/'*)
      printf '%s%s' "$HOME" "${_ravy_field#\~}"
      ;;
    *)
      printf '%s' "$_ravy_field"
      ;;
  esac
}

if [ -f "$_ravy_secrets_tsv" ]; then
  while IFS= read -r line || [ -n "${line:-}" ]; do
    case "${line%"$_ravy_cr"}" in
      ''|\#*)
        continue
        ;;
    esac
    case "$line" in
      *"$_ravy_tab"*)
        key=${line%%"$_ravy_tab"*}
        value=${line#*"$_ravy_tab"}
        ;;
      *)
        continue
        ;;
    esac
    key=$(_ravy_trim_tsv_key "${key:-}")
    value=$(_ravy_trim_tsv_value "${value:-}")
    value=$(_ravy_expand_tsv_home "${value:-}")
    [ -n "$key" ] || continue
    export "$key=$value"
  done < "$_ravy_secrets_tsv"
fi

unset _ravy_config_home _ravy_secrets_tsv _ravy_tab _ravy_cr _ravy_field line key value
unset -f _ravy_trim_tsv_key _ravy_trim_tsv_value _ravy_expand_tsv_home
