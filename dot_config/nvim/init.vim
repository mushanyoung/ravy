" Ravy Neovim entrypoint.
"
" Keep the main config under ~/.config/nvim so runtime behavior does not
" depend on the chezmoi source checkout still existing at a fixed path.

let s:config_dir = exists('*stdpath') ? stdpath('config') : fnamemodify(expand('<sfile>:p'), ':h')
let s:ravy_vimrc = s:config_dir . '/ravy.vim'

if filereadable(s:ravy_vimrc)
  let $MYVIMRC = s:ravy_vimrc
  execute 'source ' . fnameescape(s:ravy_vimrc)
else
  let $MYVIMRC = expand('<sfile>:p')
  echohl WarningMsg
  echom 'Ravy: missing main config at ' . s:ravy_vimrc
  echohl None
endif

