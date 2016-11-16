export RAVY="${0:A:h}"
export RAVY_CUSTOM="$RAVY/custom"

# make elements in path and fpath unique
typeset -U path
typeset -U fpath

# generates path
prepand_folder_to_path () {
  if [[ -d $1 ]]; then
    path[1,0]=$1
  fi
}

append_folder_to_fpath () {
  if [[ -d $1 ]]; then
    fpath+=$1
  fi
}

prepand_folder_to_path $HOME/.brew/bin
prepand_folder_to_path $RAVY/bin
prepand_folder_to_path $RAVY_CUSTOM/bin

append_folder_to_fpath $RAVY_CUSTOM/zsh-functions
append_folder_to_fpath $(brew --prefix 2>/dev/null)/completions/zsh
