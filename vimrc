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

  " restore <CR> key map in quickfix mode
  autocmd BufReadPost quickfix nnoremap <buffer> <CR> <CR>
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

" imap / cmap {{

" use `jk` to exit insert mode
inoremap jk <ESC>

" <cr>: close popup and save indent.
inoremap <expr><cr> pumvisible() ? "\<c-y>" : "\<cr>"

" tab / s-tab & c-j / c-k works just like c-n and c-p in completion
inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
inoremap <expr><s-tab> pumvisible() ? "\<c-p>" : "\<s-tab>"
inoremap <expr><c-j> pumvisible() ? "\<c-n>" : "\<c-j>"
inoremap <expr><c-k> pumvisible() ? "\<c-p>" : "\<c-k>"

" insert current opened buffer's directory in command line
cnoremap %% <C-R>=expand('%:p:h').'/'<CR>

" }}

" nmap {{

" disable arrow keys
noremap <UP> <NOP>
noremap <DOWN> <NOP>
noremap <LEFT> <NOP>
noremap <RIGHT> <NOP>

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

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap gB :bnext<CR>

" cancel hlsearch
nnoremap <silent> <CR> :nohlsearch<CR>

" use tab and s-tab to indent / unindent
nnoremap <TAB> v>
nnoremap <S-TAB> v<
vnoremap <TAB> >gv
vnoremap <S-TAB> <gv

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

" }}

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

" \ or <SPACE> {{

" map leader key to ,
let g:mapleader = ','

" use space and backslash as the actual leader key for my own key bindings
map <SPACE> \
map <SPACE><SPACE> \\

" write
nnoremap \w :write<CR>

" close current window
nnoremap <silent> \c :close<CR>

" quick substitute
vnoremap \s :s/
nnoremap \s :%s/

" go backaward and forward in jump list
nnoremap \j <C-O>
nnoremap \k <C-I>

" key to black hole
noremap \b "_

" select ALL
nnoremap \a ggVG

" forward yanked text to clip
nnoremap <silent> \y :call system('clip >/dev/tty', @0)<CR>:echo 'Yanked text sent.'<CR>

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<CR>

" change working directory to the newly opened buffer
nnoremap \h :lcd %:p:h<CR>:pwd<CR>

" reset current filetype
nnoremap <silent> \r :let &filetype=&filetype<CR>

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
nnoremap \db :call DiffOrig()<CR>
nnoremap <silent> \de :bdelete!<CR>:diffoff<CR>

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

" use \\ as the prefix
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

" search: show match index and total match count
Plug 'google/vim-searchindex'

" decent colorscheme
Plug 'jpo/vim-railscasts-theme'

" fzf integration
Plug 'junegunn/fzf', { 'dir': '~/.fzf' }

" provide utility commands to fzf in a list of certain targets
Plug 'junegunn/fzf.vim'

" extends ", @, i:<C-R> to list the contents registers
Plug 'junegunn/vim-peekaboo'

" ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-easy-align'

" vcs: make changed sections marked, text-objectified, targetable
Plug 'mhinz/vim-signify'

" launch search in working directory
Plug 'rking/ag.vim'

" highlight trailing blanks and provide StripWhitespace function
Plug 'ntpeters/vim-better-whitespace'

" file explorer
Plug 'scrooloose/nerdtree', { 'on': [('NERDTreeToggle'), 'NERDTreeFind'] }

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

if executable('ctags')
  " tag explorer
  Plug 'majutsushi/tagbar'

  " auto generate tags
  Plug 'xolox/vim-easytags'
  Plug 'xolox/vim-misc'
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

