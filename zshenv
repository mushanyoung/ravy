export RAVY="${0:A:h}"
export RAVY_CUSTOM="$RAVY/custom"

# add various folders into path
prepand_folder_to_path () {
  if [[ -d $1 ]]; then
    PATH=$1:${${PATH//$1:/}//:$1/}
  fi
}

append_folder_to_path () {
  if [[ -d $1 ]]; then
    if [[ $PATH != *${1}* ]]; then
      PATH=$PATH:$1
    fi
  fi
}

prepand_folder_to_path $HOME/.brew/bin
prepand_folder_to_path $RAVY/bin
prepand_folder_to_path $RAVY_CUSTOM/bin

