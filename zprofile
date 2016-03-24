export RAVY="${0:A:h}"
export RAVY_CUSTOM="$RAVY/custom"

# add various folders into path
rv_add_dir_to_path_begin () {
  if [[ -d $1 ]]; then
    PATH=$1:${PATH/$1:/}
  fi
}

rv_add_dir_to_path_end () {
  if [[ -d $1 ]]; then
    if [[ $PATH != *${1}* ]]; then
      PATH=$PATH:$1
    fi
  fi
}

rv_add_dir_to_path_begin $HOME/.brew/bin
rv_add_dir_to_path_end $HOME/.fzf/bin
rv_add_dir_to_path_end $RAVY/bin
rv_add_dir_to_path_end $RAVY_CUSTOM/bin

