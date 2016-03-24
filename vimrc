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

" enable syntax
syntax on

" max column number to be parsed for syntax
set synmaxcol=255

" default shell
set shell=bash

" interact with system clipboard
set clipboard+=unnamed

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

" no timeout for mapped key seqs, timeout for key code seqs
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
runtime macros/matchit.vim

" set terminal window title
" set window name instead if in tmux
set title titlestring=#%t%(\ %a%)%(\ %r%)%(\ %m%)
if &term =~ "screen*"
  set t_ts=k t_fs=\
endif

" encodings
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
set winheight=5
set winminheight=5

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
set list listchars=tab:❯\ ,trail:•,extends:>,precedes:<,nbsp:+

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
highlight ColorColumn ctermbg=236 guibg=236

" Sign Column should match background
highlight clear SignColumn

" }}

" Autocmds {{

augroup window_editing
  autocmd!

  " cursorline switched while focus is switched to another split window
  autocmd WinEnter * setlocal cursorline
  autocmd WinLeave * setlocal nocursorline
augroup END

augroup buffer_editing
  autocmd!

  " restore cursor position
  autocmd BufReadPost *
    \ if line("'\"") >= 1 && line("'\"") <= line("$") |
    \   execute "normal! g`\"" |
    \ endif

  " when editing a git commit message
  " set the cursor position to the beginning
  autocmd BufReadPost COMMIT_EDITMSG normal gg0

  " remove tailing whitespace before writing to buffer
  autocmd BufWritePre * StripWhitespace
augroup END

augroup filetypes
  autocmd!

  autocmd BufRead,BufNewFile *.m         setlocal ft=objc
  autocmd BufRead,BufNewFile *.as        setlocal ft=actionscript
  autocmd BufRead,BufNewFile *.mxml      setlocal ft=mxml
  autocmd BufRead,BufNewFile *.scss      setlocal ft=scss.css
  autocmd BufRead,BufNewFile *.less      setlocal ft=less
  autocmd BufRead,BufNewFile *.erb       setlocal ft=eruby.html
  autocmd BufRead,BufNewFile *.json      setlocal ft=json syntax=javascript
  autocmd BufRead,BufNewFile *.gitignore setlocal ft=gitignore
  autocmd BufRead,BufNewFile *.zsh-theme setlocal ft=zsh
  autocmd BufRead,BufNewFile *.fdoc      setlocal ft=yaml
  autocmd BufRead,BufNewFile *.md,*.txt  setlocal ft=markdown

  autocmd BufRead,BufNewFile *.js        setlocal makeprg=js\ %
  autocmd BufRead,BufNewFile *.pl        setlocal makeprg=perl\ %
  autocmd BufRead,BufNewFile *.php       setlocal makeprg=php\ %
  autocmd BufRead,BufNewFile *.py        setlocal makeprg=python\ %
  autocmd BufRead,BufNewFile *.rb        setlocal makeprg=ruby\ -w\ %
augroup END

" }}

" Keys {{

" disable arrow keys
noremap <UP> <NOP>
noremap <DOWN> <NOP>
noremap <LEFT> <NOP>
noremap <RIGHT> <NOP>

" use `jk` to exit insert mode
inoremap jk <ESC>

" scroll the view port faster
nnoremap <C-E> 3<C-E>
nnoremap <C-Y> 3<C-Y>

" make Y acts just like C and D
nnoremap Y y$

" swap the behavior of j/k and gj/gk
nnoremap j gj
nnoremap k gk
nnoremap gj j
nnoremap gk k

" remap VIM 0
nnoremap 0 ^
nnoremap ^ 0

" quick substitute
vnoremap \s :s/
nnoremap \s :%s/

" cancel hlsearch
nnoremap <silent> <CR> :nohlsearch<CR>

" use tab and s-tab to indent / unindent
nnoremap <TAB> v>
nnoremap <S-TAB> v<
vnoremap <TAB> >gv
vnoremap <S-TAB> <gv

" similar to gf, open file path under cursor, but in a split window in right
nnoremap gw :let mycurf=expand("<cfile>")<CR>:execute("vsplit ".mycurf)<CR>

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

" invoke make with makeprg option
nnoremap <F6> :make<CR>

" highlight repeated lines
nnoremap <silent> \tr :syn clear Repeat<CR>:g/^\(.*\)\n\ze\%(.*\n\)*\1$/exe 'syn match Repeat "^' . escape(getline('.'), '".\^$*[]') . '$"'<CR>:nohlsearch<BAR>echo 'Repeated lines highlighted.'<CR>

" Windows {{

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
noremap <silent> <C-W><C-H> :call WinMove('h')<CR>
noremap <silent> <C-W><C-J> :call WinMove('j')<CR>
noremap <silent> <C-W><C-K> :call WinMove('k')<CR>
noremap <silent> <C-W><C-L> :call WinMove('l')<CR>

" window resize
noremap <C-W>0 :resize +5<CR>
noremap <C-W>9 :resize -5<CR>
noremap <C-W>. :vertical resize +10<CR>
noremap <C-W>, :vertical resize -10<CR>

" split window
noremap <C-W>\ :vsplit<CR>
noremap <C-W>- :split<CR>

" }}

" map leader key to ,
let g:mapleader = ','

" use space and backslash as the actual leader key for my own key bindings
map <SPACE> \
map <SPACE><SPACE> \\

" insert an empty line without entering insert mode
nmap \<CR> <PLUG>unimpairedBlankDown<CR>
nmap \\<CR> <PLUG>unimpairedBlankUp<CR>

" copy current line
nnoremap \<C-Y> "tyy"tp0

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<CR>

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

" go backaward and forward in jump list
nnoremap \j <C-O>
nnoremap \k <C-I>

" key to black hole
noremap \b "_

" reset current filetype
nnoremap <silent> \r :let &filetype=&filetype<CR>

" toggle auto zz when scrolling
nnoremap <silent> \zz :let &scrolloff=999-&scrolloff<CR>

" diff current buffer to its original (saved) version
function! DiffOrig()
  diffthis
  vnew %:p.orig
  set bt=nofile
  r ++edit #
  0d_
  diffthis
endfunction
nnoremap \db :call DiffOrig()<CR>
nnoremap <silent> \de :bdelete!<CR>:diffoff<CR>

" forward yanked text to clip
nnoremap <silent> \y :call system('clip >/dev/tty', @0)<CR>:echo 'Yanked text sent.'<CR>

" select ALL
nnoremap \a ggVG

" open / reload vimrc
nnoremap \ve :edit $MYVIMRC<CR>
nnoremap \vs :source $MYVIMRC<CR>

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

" write
nnoremap \w :write<CR>

" close current window
nnoremap <silent> \c :close<CR>

" change working directory to the newly opened buffer
nnoremap \h :lcd %:p:h<CR>:pwd<CR>

" Buffer {{

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap \fp :bprevious<CR>
nnoremap gB :bnext<CR>
nnoremap \fn :bnext<CR>

" close current buffer
nnoremap \fd :bdelete!<CR>

" new buffer
nnoremap \fn :enew<CR>

" print full path of current buffer
nnoremap \fp :echo expand('%:p')<CR>

" insert current opened buffer's directory in command line
cnoremap %% <C-R>=expand('%:p:h').'/'<CR>

" }}

" }}

" Plugin Settings {{

" Completion {{

" <CR>: close popup and save indent.
inoremap <expr><CR> pumvisible() ? "\<C-Y>" : "\<CR>"

" Tab / S-Tab & C-J / C-K works just like C-N and C-P in completion
inoremap <expr><TAB> pumvisible() ? "\<C-N>" : "\<TAB>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-P>" : "\<S-TAB>"
inoremap <expr><C-J> pumvisible() ? "\<C-N>" : "\<C-J>"
inoremap <expr><C-K> pumvisible() ? "\<C-P>" : "\<C-K>"

" }}

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

" fzf {{

nnoremap <silent> \fo :Files<CR>
nnoremap <silent> \fs :Buffers<CR>
nnoremap <silent> \ft :BTags<CR>
nnoremap <silent> \fm :Marks<CR>
nmap <C-P> \fo

" }}

" nerdtree {{

nnoremap <silent> <F2> :NERDTreeToggle<CR>
nnoremap \ff :NERDTreeFind<CR>

let g:NERDTreeShowBookmarks=0
let g:NERDTreeMinimalUI=1
let g:NERDTreeDirArrows=1
let g:NERDTreeWinSize=30

" }}

" vim-airline {{

let g:airline_powerline_fonts=1

" }}

" vim-easy-align {{

xmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

" }}

" vim-easymotion {{

" Also use \\ as the prefix
nmap \\ <PLUG>(easymotion-prefix)

" Turn on case insensitive feature
let g:EasyMotion_smartcase = 1

" }}

" vim-signify {{

nmap \n <PLUG>(signify-next-hunk)
nmap \p <PLUG>(signify-prev-hunk)

omap ic <PLUG>(signify-motion-inner-pending)
xmap ic <PLUG>(signify-motion-inner-visual)
omap ac <PLUG>(signify-motion-outer-pending)
xmap ac <PLUG>(signify-motion-outer-visual)

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

Plug 'ConradIrwin/vim-bracketed-paste'
Plug 'PeterRincker/vim-argumentative'
Plug 'Valloric/MatchTagAlways'
Plug 'ap/vim-css-color'
Plug 'vim-airline/vim-airline'
Plug 'easymotion/vim-easymotion'
Plug 'google/vim-searchindex'
Plug 'jiangmiao/auto-pairs'
Plug 'jpo/vim-railscasts-theme'
Plug 'junegunn/fzf', { 'dir': '~/.fzf' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-peekaboo'
Plug 'junegunn/vim-easy-align'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'majutsushi/tagbar'
Plug 'mhinz/vim-signify'
Plug 'ntpeters/vim-better-whitespace'
Plug 'rking/ag.vim'
Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
Plug 'scrooloose/syntastic'
Plug 'sheerun/vim-polyglot'
Plug 'terryma/vim-expand-region'
Plug 'terryma/vim-multiple-cursors'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-ragtag'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'xolox/vim-easytags'
Plug 'xolox/vim-misc'

if v:version >= 704
  Plug 'SirVer/ultisnips'
  Plug 'honza/vim-snippets'
endif

if exists('g:rv_ycm_enable')
  Plug 'Valloric/YouCompleteMe'
endif

call plug#end()

" set colorscheme to railscasts if it is not specified
if !exists('g:colors_name')
  colorscheme railscasts
endif

" }}

