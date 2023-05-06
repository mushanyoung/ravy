#!/usr/bin/env bash

# Unarchives files.
# Always put unarchived files in a folder with the same name, unless there's already a top-level folder.

if [ -z "$1" ]; then
  echo "usage: ${0} <archive_name.ext>..."
  exit 2
fi

function count_top_level_entries {
  local count=0
  while read -r _; do
    count=$((count + 1))
  done <<< "$1"
  echo $count
}

for file in "${@}"; do
  dir="${file%.*}"
  file="$(realpath "${file}")"
  single_top_level_folder=true
  case "${file}" in
    (*.zip)
      entries=$(unzip -l "${file}" | awk 'NR > 3 {print $4}' | grep -v "/$")
      count=$(count_top_level_entries "${entries}")
      single_top_level_folder=$((count == 1))
      ;;
    (*.rar)
      entries=$(unrar l "${file}" | awk '/^-+$/ && p {print l; p=0}; {l=$0; p=1}' | grep -v "/$")
      count=$(count_top_level_entries "${entries}")
      single_top_level_folder=$((count == 1))
      ;;
    (*.tar|*.tar.bz|*.tar.bz2|*.tbz|*.tbz2|*.tar.gz|*.tgz|*.tar.lzma|*.tlz|*.tar.xz|*.txz|*.tar.zst|*.tzst)
      entries=$(tar -tf "${file}" | awk -F/ '{print $1"/"}' | uniq)
      count=$(count_top_level_entries "${entries}")
      single_top_level_folder=$((count == 1))
      ;;
    (*.7z|*.001)
      entries=$(7za l "${file}" | awk '/^-+$/ && p {print l; p=0}; {l=$0; p=1}' | grep -v "/$")
      count=$(count_top_level_entries "${entries}")
      single_top_level_folder=$((count == 1))
      ;;
    (*) echo "${0}: unknown archive type: ${file}"; continue ;;
  esac

  if [ "${single_top_level_folder}" == "true" ]; then
    outdir="."
  else
    outdir="${dir}"
    mkdir -p "${outdir}"
    echo "Creating folder: ${dir}"
  fi

  cd "${outdir}" || exit
  case "${file}" in
    (*.7z|*.001) 7za x "${file}" ;;
    (*.rar) unrar x -ad "${file}" ;;
    (*.tar.bz|*.tar.bz2|*.tbz|*.tbz2) tar -xvjf "${file}" ;;
    (*.tar.gz|*.tgz) tar -xvzf "${file}" ;;
    (*.tar.lzma|*.tlz) tar --lzma --help &>/dev/null && XZ_OPT=-T0 tar --lzma -xvf "${file}" \
      || lzcat "${file}" | tar -xvf - ;;
    (*.tar.xz|*.txz) tar -J --help &>/dev/null && XZ_OPT=-T0 tar -xvJf "${file}" \
      || xzcat "${file}" | tar -xvf - ;;
    (*.tar.zst|*.tzst) XZ_OPT=-T0 tar --use-compress-program=unzstd -xvf "${file}" ;;
    (*.tar) tar -xvf "${file}" ;;
    (*.zip) unzip "${file}" ;;
    (*.bz|*.bz2) bunzip2 "${file}" ;;
    (*.gz) gunzip "${file}";;
    (*.lzma) unlzma -T0 "${file}" ;;
    (*.xz) unxz -T0 "${file}" ;;
    (*.zst) zstd -T0 -d "${file}" ;;
    (*.Z) uncompress "${file}" ;;
    (*) echo "${0}: unknown archive type: ${file}" ;;
  esac
  cd .. || exit
done
