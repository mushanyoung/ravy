" ChezMoi shim: keep the real config in the Ravy repo.
"
" This avoids duplicating the full vimrc into ChezMoi source state while still
" installing a standard Neovim entry point.

let s:ravy_home = $RAVY_HOME

if empty(s:ravy_home)
  if executable('chezmoi')
    let s:ravy_home = system('chezmoi source-path')
    let s:ravy_home = substitute(s:ravy_home, '\n\+$', '', '')
  elseif isdirectory(expand('~/.local/share/chezmoi'))
    let s:ravy_home = expand('~/.local/share/chezmoi')
  else
    let s:ravy_home = expand('~/.ravy')
  endif
endif

let s:vimrc = s:ravy_home . '/vimrc'
if filereadable(s:vimrc)
  execute 'source ' . fnameescape(s:vimrc)
endif


