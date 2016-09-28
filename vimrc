" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker filetype=vim:
" }}

" General Settings {{

" histories and storages
set backupdir=~/.vim/tmp/,.
set undodir=~/.vim/tmp//,.
set directory=~/.vim/tmp//,.
set nobackup writebackup
set swapfile
set undofile undolevels=1000 undoreload=10000
set history=10000

" session options
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize

" max column number to be parsed for syntax
set synmaxcol=255

" default shell
set shell=bash

" when switching to a buffer, jump to the window if there is one with it opened
set switchbuf=useopen

" enable mouse by default
set mouse=a

" enable vim modeline and its search range
set modeline modelines=9

" last window always have a status line
set laststatus=2

" hidden buffer
set hidden

" does not move the cursor to start of line for some commands
set nostartofline

" no timeout for mapped key sequence, timeout for key code sequence
set notimeout timeoutlen=1000 ttimeout ttimeoutlen=100

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

" no spell check
set nospell

" auto read when file is changed from outside
set autoread

" no Byte Order Mark
set nobomb

" split window: vertical to the right and horizontal to the below
set splitright splitbelow

" search: smart case, incremental & highlight
set ignorecase smartcase hlsearch incsearch

" indent
set copyindent smartindent nocindent
filetype plugin indent on

" Show matched brackets/parenthesis, enable extended % matching
set showmatch
set matchpairs+=<:>
runtime macros/matchit.vim

" set terminal title or terminal multiplexer window name
set title titlestring=#%t%(\ %a%)%(\ %r%)%(\ %m%)
if &term =~ "screen*"
  set t_ts=k t_fs=\
endif

" encodings
set encoding=utf-8
set fileencoding=utf-8
set termencoding=utf-8
set fileencodings=utf-8,big5,gbk,euc-jp,euc-kr,iso8859-1,utf-16le,latin1
scriptencoding utf-8

" ignores output objects / media formats / VCS files
set wildignore+=*.o,*.obj,*.pyc
set wildignore+=*.png,*.jpg,*.gif,*.ico
set wildignore+=*.swf,*.fla
set wildignore+=*.mp3,*.mp4,*.avi,*.mkv
set wildignore+=*.git*,*.hg*,*.svn*
set wildignore+=*sass-cache*
set wildignore+=*.DS_Store
set wildignore+=log/**
set wildignore+=tmp/**

" }}

" UI Settings {{

set wrap
set linebreak
set background=dark
set tabpagemax=50
set noruler
set noshowmode
set showcmd
set lazyredraw
set cursorline
set display=lastline

" auto formatting options
set formatoptions=nmMcroql
if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j " Delete comment character when joining commented lines
endif

" line number
set number numberwidth=4

" visual bell on errors
set visualbell

" show tab when multi tabs exist
set showtabline=1

" Tab completion:
" Show list instead of just completing
" list matches, then longest common part, then all.
set wildmenu wildmode=list:longest,full

" Backspace and cursor keys wrap too
set whichwrap=b,s,h,l,<,>,[,]

" 5 lines away from margins to scroll 1 line
set scrolloff=5 scrolljump=1

" Prefer whitespace than tab
set tabstop=8 softtabstop=2 shiftwidth=2 expandtab smarttab

" show hideen characters
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.

" Abbreviation of file messages: try <C-G>
set shortmess+=filmnrxoOtT

" Allow for cursor beyond last character
set virtualedit=onemore

" Better Unix / Windows compatibility
set viewoptions=folds,options,cursor,unix,slash

" fold everything based on indent, but disable by default
set nofoldenable foldmethod=indent foldlevel=0

" highlight over width boundary
set textwidth=80
set colorcolumn=+1

" Sign Column should match background
highlight clear SignColumn

" }}

" Autocmds {{

augroup buffer_editing
  autocmd!

  " remove trailing whitespace before writing to buffer
  autocmd BufWritePre * StripWhitespace

  " restore cursor position
  autocmd BufReadPost *
        \ if line("'\"") >= 1 && line("'\"") <= line("$") |
        \   execute "normal! g`\"" |
        \ endif

  " when editing a git commit message
  " set the cursor position to the beginning
  autocmd BufReadPost COMMIT_EDITMSG normal gg0
augroup END

augroup filetypes
  autocmd!

  " set make program for scripting languages
  autocmd BufRead,BufNewFile *.js  setlocal makeprg=js\ %
  autocmd BufRead,BufNewFile *.pl  setlocal makeprg=perl\ %
  autocmd BufRead,BufNewFile *.php setlocal makeprg=php\ %
  autocmd BufRead,BufNewFile *.py  setlocal makeprg=python\ %
  autocmd BufRead,BufNewFile *.rb  setlocal makeprg=ruby\ -w\ %
augroup END

" }}

" Keys {{

" Window {{

" Move to a window in the given direction, if can't move, create a new one
function! WinMove(direction)
  let t:curwin = winnr()
  exec "wincmd ".a:direction
  if (t:curwin == winnr())
    exec "wincmd ".(match(a:direction,'[jk]') ? 'v' : 's')
    exec "wincmd ".a:direction
  endif
endfunction

noremap <silent> <C-W>h :call WinMove('h')<CR>
noremap <silent> <C-W>j :call WinMove('j')<CR>
noremap <silent> <C-W>k :call WinMove('k')<CR>
noremap <silent> <C-W>l :call WinMove('l')<CR>

" window resize
noremap <C-W>0 :resize +5<CR>
noremap <C-W>9 :resize -5<CR>
noremap <C-W>. :vertical resize +5<CR>
noremap <C-W>, :vertical resize -5<CR>

" split window
noremap <C-W>\ :vsplit<CR>
noremap <C-W>- :split<CR>

" integrate tmux navigator
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> h :TmuxNavigateLeft<CR>
nnoremap <silent> j :TmuxNavigateDown<CR>
nnoremap <silent> k :TmuxNavigateUp<CR>
nnoremap <silent> l :TmuxNavigateRight<CR>
nnoremap <silent> p :TmuxNavigatePrevious<CR>
nnoremap <silent> c :close<CR>

" }}

" imap / cmap {{

" jk to exit insert mode
inoremap jk <ESC>

" <CR>: close popup and save indent.
inoremap <expr><CR> pumvisible() ? "\<C-Y>" : "\<CR>"

" c-j / c-k works just like c-n and c-p in completion
inoremap <expr><C-J> pumvisible() ? "\<C-N>" : "\<C-J>"
inoremap <expr><C-K> pumvisible() ? "\<C-P>" : "\<C-K>"

" insert current opened buffer's directory in command line
cnoremap %% <C-R>=expand('%:p:h').'/'<CR>

" C-P, C-N to prefix search in history
cnoremap <C-P> <UP>
cnoremap <C-N> <DOWN>
cnoremap <UP> <C-P>
cnoremap <DOWN> <C-N>

" type w!! in command line mode to force write to a RO file
cnoremap w!! w !sudo tee % >/dev/null

" }}

" nmap / vmap {{

" map leader key to >
let g:mapleader = '>'

" use space and backslash as the actual leader key for my own key bindings
map <SPACE> \
map <SPACE><SPACE> \\

" disable arrow keys
noremap <UP> <NOP>
noremap <DOWN> <NOP>
noremap <LEFT> <NOP>
noremap <RIGHT> <NOP>

" scroll the view port faster
nnoremap <C-E> 3<C-E>
nnoremap <C-Y> 3<C-Y>

" j, k travels visual line and gj, gk travels real line
nnoremap j gj
nnoremap k gk
nnoremap gj j
nnoremap gk k

" 0 go to first non blank, ^ go to the very beginning
nnoremap 0 ^
nnoremap ^ 0

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap gB :bnext<CR>

" clear screen and cancel hlsearch
nnoremap <silent> <C-L> :noh<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>

" similar to gf, open file path under cursor, but in a split window in right
nnoremap gw :let mycurf=expand("<cfile>")<CR>:execute("vsplit ".mycurf)<CR>

" invoke make with makeprg option
nnoremap <F6> :make<CR>

" execute current buffer in shell
function! ExecuteBufferInShell()
  write
  silent !cp %:p %:p~tmp
  silent !chmod +x %:p~tmp
  silent !%:p~tmp 2>&1 | tee /tmp/exec-output
  silent !rm -f %:p~tmp
  split /tmp/exec-output
  redraw!
endfunction
nnoremap <F5> :call ExecuteBufferInShell()<CR>

" write
nnoremap \w :write<CR>

" quick substitute
vnoremap \c :s/
nnoremap \c :%s/

" select ALL
nnoremap \a ggVG

" indent / unindent
nnoremap \<TAB> v>
nnoremap \<S-TAB> v<
vnoremap \<TAB> >gv
vnoremap \<S-TAB> <gv

" forward yanked text to clip
nnoremap <silent> \y :call system('clip >/dev/tty', @0)<CR>:echo 'Yanked text sent.'<CR>

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<CR>

" change working directory to the newly opened buffer
nnoremap \fh :lcd %:p:h<CR>:pwd<CR>

" close current buffer
nnoremap \fd :bdelete!<CR>

" new buffer
nnoremap \fn :enew<CR>

" print full path of current buffer
nnoremap \fp :echo expand('%:p')<CR>

" toggle auto zz when scrolling
nnoremap <silent> \zz :let &scrolloff=999-&scrolloff<CR>

" insert an empty line without entering insert mode
nmap \<CR> <PLUG>unimpairedBlankDown<CR>
nmap \\<CR> <PLUG>unimpairedBlankUp<CR>

" copy current line
nnoremap \<C-Y> "tyy"tp0

" open / reload vimrc
nnoremap \ve :edit $MYVIMRC<CR>
nnoremap \vs :source $MYVIMRC<CR>

" highlight repeated lines
nnoremap <silent> \tr :syn clear Repeat<CR>:g/^\(.*\)\n\ze\%(.*\n\)*\1$/exe 'syn match Repeat "^' . escape(getline('.'), '".\^$*[]') . '$"'<CR>:nohlsearch<BAR>echo 'Repeated lines highlighted.'<CR>

" open quick fix window
function! ToggleQuickFix()
  if exists("g:qfix_win")
    cclose
    unlet g:qfix_win
  else
    copen
    let g:qfix_win = bufnr("$")
  endif
endfunction
nnoremap <silent>\q :call ToggleQuickFix()<CR>

" diff current buffer to its original (saved) version
function! DiffOrig()
  diffthis
  vnew %:p.orig
  set bt=nofile
  r ++edit #
  0d_
  diffthis
endfunction
nnoremap \do :call DiffOrig()<CR>
nnoremap <silent> \de :bdelete!<CR>:diffoff<CR>
nnoremap <silent> \dgl :diffget 1<CR>:diffupdate<CR>
nnoremap <silent> \dgb :diffget 2<CR>:diffupdate<CR>
nnoremap <silent> \dgr :diffget 3<CR>:diffupdate<CR>

" print current key maps in a new buffer
function! ListAllkeyMaps()
  enew
  redir => allkeymaps
  silent map
  silent imap
  silent cmap
  redir END
  put =allkeymaps
endfunction
nnoremap \vm :call ListAllkeyMaps()<CR>

" toggle mouse
function! ToggleMouse()
  if &mouse == 'a'
    set mouse=
    echo 'Mouse Disabled'
  else
    set mouse=a
    echo 'Mouse Enabled'
  endif
endfunction
nnoremap <silent>\m :call ToggleMouse()<CR>

" file explorer by ranger
function! RangerFileExplorer()
  let temp = tempname()
  if has("gui_running")
    exec 'silent !xterm -e ranger --choosefiles=' . shellescape(temp)
  else
    exec 'silent !ranger --choosefiles=' . shellescape(temp)
  endif
  if !filereadable(temp)
    redraw!
    " Nothing to read.
    return
  endif
  let names = readfile(temp)
  if empty(names)
    redraw!
    " Nothing to open.
    return
  endif
  " Edit the first item.
  exec 'edit ' . fnameescape(names[0])
  " Add any remaning items to the arg list/buffer list.
  for name in names[1:]
    exec 'argadd ' . fnameescape(name)
  endfor
  redraw!
endfunction
nnoremap \ff :call RangerFileExplorer()<CR>

" }}

" }}

" Plugin Settings {{

" Tags {{

nnoremap <F4> :TagbarToggle<CR>

let g:easytags_async=1
let g:easytags_always_enabled=1

" }}

" ag.vim {{

" if silver searcher is not installed, use `ack` instead
if !executable("ag")
  let g:ag_prg="ack --column"
endif

nnoremap FF :Ag<SPACE>

" }}

" auto-pairs {{

let g:AutoPairsShortcutToggle=''

" }}

" fzf {{

nnoremap <silent> o   :Files<CR>
nnoremap <silent> \fo   :Files<CR>
nnoremap <silent> \ft   :BTags<CR>
nnoremap <silent> \fk   :Marks<CR>
nnoremap <silent> \fs   :Buffers<CR>
nnoremap <silent> \b    :Buffers<CR>

" }}

" vim-airline {{

let g:airline_powerline_fonts=1

" }}

" vim-autoformat {{

nnoremap <silent>\fm :Autoformat<CR>

" }}

" vim-easy-align {{

xmap ga <PLUG>(EasyAlign)
nmap ga <PLUG>(EasyAlign)

" }}

" vim-easyclip {{

let g:EasyClipUsePasteToggleDefaults = 0

nmap p <PLUG>EasyClipSwapPasteForward
nmap n <PLUG>EasyClipSwapPasteBackwards

" }}

" vim-easymotion {{

" use \\ as the prefix
nmap \\ <PLUG>(easymotion-prefix)

" Turn on case insensitive feature
let g:EasyMotion_smartcase = 1

" }}

" vim-gitgutter {{

let g:gitgutter_map_keys = 0

nmap \hn <PLUG>GitGutterNextHunk
nmap \hp <PLUG>GitGutterPrevHunk

nmap \hu <PLUG>GitGutterUndoHunk
nmap \hs <PLUG>GitGutterStageHunk
nmap \hv <PLUG>GitGutterPreviewHunk

nmap \hb :let g:gitgutter_diff_base=''<LEFT>

omap ic <PLUG>GitGutterTextObjectInnerPending
omap ac <PLUG>GitGutterTextObjectOuterPending
xmap ic <PLUG>GitGutterTextObjectInnerVisual
xmap ac <PLUG>GitGutterTextObjectOuterVisual

" }}

" vim-peekaboo {{

let g:peekaboo_window = 'vertical leftabove 30new'

" }}

" vim-polyglot {{

" disable jsx syntax for .js file
let g:jsx_ext_required = 1

" }}

" vim-session {{

let g:session_autosave = 'yes'
let g:session_autoload = 'no'

function! OpenSessionFZF()
  function! SessionSink(line)
    return xolox#session#open_cmd(a:line, '', 'OpenSession')
  endfunction

  return fzf#run({
    \ 'source': xolox#session#get_names(0),
    \ 'sink': function('SessionSink'),
    \ 'options': '+m --prompt="Session> "',
    \ 'down': '~40%'})
endfunction
nnoremap \so :call OpenSessionFZF()<CR>
nmap s \so

nnoremap \sn :SaveSession<SPACE>
nnoremap \sd :DeleteSession<SPACE>
nnoremap \ss :SaveSession<CR>
nnoremap \sc :CloseSession<CR>
nnoremap \sv :ViewSession<CR>

nnoremap \sf :echo 'Current Session: ' . xolox#session#find_current_session()<CR>

" }}

" vim-surround {{

let g:surround_113="#{\r}"     " v
let g:surround_35="#{\r}"      " #
let g:surround_45="<% \r %>"   " -
let g:surround_61="<%= \r %>"  " =

" }}

" ultisnips {{

let g:UltiSnipsExpandTrigger="<C-D>"
let g:UltiSnipsListSnippets="<C-U>"
let g:UltiSnipsJumpForwardTrigger="<C-B>"
let g:UltiSnipsJumpBackwardTrigger="<C-Z>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" }}

" }}

" Custom Settings {{

if filereadable($RAVY_CUSTOM."/vimrc")
  source $RAVY_CUSTOM/vimrc
endif

if isdirectory($RAVY_CUSTOM."/vim")
  set rtp+=$RAVY_CUSTOM/vim
endif

" }}

" Plugins {{

" setup plugins
call plug#begin('~/.vim/bundle')

" auto paste mode when pasting from terminal
Plug 'ConradIrwin/vim-bracketed-paste'

" argument: [, ], to jump & <, >, to shift & a, i, is text-object
Plug 'PeterRincker/vim-argumentative'

" always highlight matching markup language tags
Plug 'Valloric/MatchTagAlways'

" show css color in code
Plug 'ap/vim-css-color'

" status line with powerline fonts
Plug 'vim-airline/vim-airline'

" choose from positions which repeated motions would reach
Plug 'easymotion/vim-easymotion'

" s: motion to match 2 characters
Plug 'justinmk/vim-sneak'

" search: show match index and total match count
Plug 'google/vim-searchindex'

" decent colorscheme
Plug 'jpo/vim-railscasts-theme'

" fzf integration
Plug 'junegunn/fzf'

" provide utility commands to fzf in a list of certain targets
" install to a different name to work around plugin detection issue of maktaba
Plug 'junegunn/fzf.vim', {'dir': '~/.vim/bundle/fzf-utils'}

" extends ", @, i:<C-R> to list the contents registers
Plug 'junegunn/vim-peekaboo'

" better clipboard of vim
Plug 'svermeulen/vim-easyclip'

" ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-easy-align'

" git: hunks operation indicator
Plug 'airblade/vim-gitgutter'

" launch search in working directory
Plug 'rking/ag.vim'

" highlight trailing blanks and provide StripWhitespace function
Plug 'ntpeters/vim-better-whitespace'

" check code syntax
Plug 'scrooloose/syntastic'

" a set of filetype plugins
Plug 'sheerun/vim-polyglot'

" +, - to expand and shrink selection
Plug 'terryma/vim-expand-region'

" multiple cursors and multiple modifications
Plug 'terryma/vim-multiple-cursors'

" Insert or delete brackets, parens, quotes in pair
Plug 'jiangmiao/auto-pairs'

" gc to comment codes
Plug 'tpope/vim-commentary'

" `s`: manipulate surrounded symbols / texts
Plug 'tpope/vim-surround'

" `.` supports to repeat mapped key sequence
Plug 'tpope/vim-repeat'

" a bunch of useful [, ] key bindings
Plug 'tpope/vim-unimpaired'

" git integration
Plug 'tpope/vim-fugitive'

" vim plugin util
Plug 'xolox/vim-misc'

" session manager
Plug 'xolox/vim-session'

" code or diff reviews
Plug 'junkblocker/patchreview-vim'

" simulated scroll bar using sign column
Plug 'vim-scripts/vim-scroll-position'

" pane navigate integration with tmux
Plug 'christoomey/vim-tmux-navigator'

" Auto format
Plug 'Chiel92/vim-autoformat'

" Interactive scratchpad
Plug 'metakirby5/codi.vim'

if executable('ctags')
  " tag explorer
  Plug 'majutsushi/tagbar'

  " auto generate tags
  Plug 'xolox/vim-easytags'
endif

if v:version >= 704
  " snippets
  Plug 'SirVer/ultisnips'
  Plug 'honza/vim-snippets'
endif

call plug#end()

" default colorscheme
if !exists('g:colors_name')
  colorscheme railscasts
endif

" }}

