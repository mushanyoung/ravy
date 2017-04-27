" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker filetype=vim:
" }}

" Settings {{

" General
set backupdir=~/.vim/tmp/,. nobackup writebackup
set directory=~/.vim/tmp//,. swapfile
set undodir=~/.vim/tmp//,. undofile undolevels=1000 undoreload=10000
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
set wildignore+=*.png,*.jpg,*.gif,*.ico,*.mp3,*.mp4,*.avi,*.mkv,*.o,*.obj,*.pyc,*.swf,*.fla,*.git*,*.hg*,*.svn*,*sass-cache*,log/**,tmp/**,*~,*~orig,*.DS_Store,tags,.tags,.tags_sorted_by_file,node_modules
set encoding=utf-8 termencoding=utf-8 fileencoding=utf-8 fileencodings=utf-8,big5,gbk,euc-jp,euc-kr,iso8859-1,utf-16le,latin1
set tabstop=8 softtabstop=2 shiftwidth=2 expandtab smarttab
set ignorecase smartcase hlsearch incsearch
set copyindent smartindent nocindent
set modeline modelines=9
set history=10000
set shell=bash
set mouse=a
set autoread
set formatoptions=nmMcroqlj
set ttimeout ttimeoutlen=100   " timeout for key code sequence
set notimeout                  " no timeout for key map sequence
set backspace=indent,eol,start " allow backspacing over everything in insert mode
set splitright splitbelow      " split window: vertical to the right and horizontal to the below
set hidden                     " hidden buffers
set nospell                    " no spell check
set nobomb                     " no Byte Order Mark
set synmaxcol=255              " max columnlength for syntax parsing
set switchbuf=useopen          " when switching to a buffer, jump to a window with it opened
set laststatus=2               " last window always have a status line
set nostartofline              " does not move the cursor to start of line for some commands
set clipboard=unnamed          " use the OS clipboard by default

" UI
set number numberwidth=4
set nofoldenable foldmethod=indent foldlevel=0
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.
set showmatch matchpairs+=<:>
set viewoptions=folds,options,cursor,unix,slash
set title titlestring=#%t%(\ %a%)%(\ %r%)%(\ %m%)
set linebreak
set background=dark
set tabpagemax=50
set noruler
set noshowmode
set showcmd
set lazyredraw
set cursorline
set display=lastline
set visualbell
set textwidth=80
set wildmenu wildmode=list:longest,full " completions: list matches, then longest common part, then all.
set wrap whichwrap=b,s,h,l,<,>,[,]      " Backspace and cursor keys wrap too
set showtabline=1                       " show tab when multi tabs exist
set virtualedit=onemore                 " cursor beyond last character
set colorcolumn=+1                      " highlight over width boundary
set scrolloff=4 scrolljump=1            " 4 lines away from margins to scroll 1 line
set shortmess+=filmnrxoOtT              " Abbreviation of file messages: try <C-G>

if &term =~ "screen*" | set t_ts=k t_fs=\ | endif " escape string for window name of screen
runtime macros/matchit.vim                            " enable extended % matching
highlight clear SignColumn                            " Sign Column should match background
scriptencoding utf-8
filetype plugin indent on

" }}

" Autocmds {{

augroup buffer_editing
  autocmd!

  autocmd BufWritePre * StripWhitespace

  " restore cursor position when read a buffer
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif

  " set the cursor position to the beginning when editing commit message
  autocmd BufReadPost COMMIT_EDITMSG normal gg0
augroup END

" }}

" Functions {{

" Get visual selection text
function! GetVisualSelection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction

" send text to [remote] clipboard
function! RavyClip(text)
  silent call system('clip >/dev/tty', a:text)
endfunction

" open a link remotely
function! RavyOpenLink(url)
  let t:url = substitute(a:url, "[\x0d\x0a].*", "", "")
  let t:url = substitute(t:url, '^\s\+', "", "")
  let t:url = (t:url =~ '.*://' ? '' : 'http://') . t:url
  call RavyClip("open\x0d" . t:url)
endfunction

" Move to a window in the given direction, if can't move, create a new one
function! RavyWinMove(direction)
  let t:curwin = winnr()
  exec "wincmd ".a:direction
  if (t:curwin == winnr())
    exec "wincmd ".(match(a:direction,'[jk]') ? 'v' : 's')
    exec "wincmd ".a:direction
  endif
endfunction

" diff current buffer to its original (saved) version
function! RavyDiffOrig()
  diffthis
  vnew %:p.orig
  set bt=nofile
  r ++edit #
  0d_
  diffthis
endfunction

" fzf to select a directory to change to
function! RavyDirectories()
  function! DirectorySink(line)
    exec "cd " . a:line
    pwd
  endfunction

  return fzf#run({
        \ 'source': '(echo ./..; find . -type d -not -path "*/\.*" | sed 1d) | cut -b3-',
        \ 'sink': function('DirectorySink'),
        \ 'options': '+m --prompt="Dir> "',
        \ 'down': '~40%'})
endfunction

" }}

" Keys {{

" basic key remap {{

" disable arrow keys
noremap <UP> <NOP>
noremap <DOWN> <NOP>
noremap <LEFT> <NOP>
noremap <RIGHT> <NOP>

" scroll the view port faster
nnoremap <C-E> 3<C-E>
nnoremap <C-Y> 3<C-Y>

" 0 go to first non blank, ^ go to the very beginning
nnoremap 0 ^
nnoremap ^ 0

" clear screen and cancel hlsearch
nnoremap <silent> <C-L> :noh<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>

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

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap gB :bnext<CR>

" similar to gf, open file path under cursor, but in a split window in right
nnoremap gw :let mycurf=expand("<cfile>")<BAR>exec("vsplit ".mycurf)<CR>

" window resize & split
noremap <C-W>0 :resize +5<CR>
noremap <C-W>9 :resize -5<CR>
noremap <C-W>. :vertical resize +5<CR>
noremap <C-W>, :vertical resize -5<CR>
noremap <C-W>\ :vsplit<CR>
noremap <C-W>- :split<CR>

" map leader key to >
let g:mapleader = '>'

" use space and backslash as the actual leader key for my own key bindings
map <SPACE> \
map <SPACE><SPACE> \\

" select ALL
nnoremap \a ggVG

" substitute
vnoremap \c :s/
nnoremap \c :%s/

" diff
nnoremap \do :call RavyDiffOrig()<CR>
nnoremap <silent> \de :bdelete!<BAR>diffoff<CR>
nnoremap <silent> \dl :diffget 1<BAR>diffupdate<CR>
nnoremap <silent> \db :diffget 2<BAR>diffupdate<CR>
nnoremap <silent> \dr :diffget 3<BAR>diffupdate<CR>

" file, buffer, working directory
" print current working directory and path of current buffer
nnoremap \ff :echo getcwd().' > '. expand('%')<CR>
" change working directory
nnoremap \f. :lcd ..<BAR>pwd<CR>
nnoremap \fh :lcd %:p:h<BAR>pwd<CR>
nnoremap \fe :lcd<SPACE>
" new buffer
nnoremap \fn :enew<CR>
" close current buffer
nnoremap \fd :Bdelete!<CR>

" \h*: GitGutter

nnoremap <silent> \l :call RavyOpenLink(@0)<BAR>echo 'Link Sent'<CR>
vnoremap <silent> \l :call RavyOpenLink(GetVisualSelection())<CR>

" toggle mouse
nnoremap <silent> \m :exec &mouse!=''?"set mouse=<BAR>echo 'Mouse Disabled.'":"set mouse=a<BAR>echo 'Mouse Enabled.'"<CR>

" toggle quick fix window
nnoremap <silent> \q :exec exists('g:qfwin')?'cclose<BAR>unlet g:qfwin':'copen<BAR>let g:qfwin=bufnr("$")'<CR>

" \s*: vim-session

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<BAR>echo &foldenable?'Fold enabled.':'Fold disabled.'<CR>

" edit / reload vimrc
nnoremap \ve :edit $MYVIMRC<CR>
nnoremap \vs :source $MYVIMRC<CR>

" print key maps in a new buffer
nnoremap \vm :enew<BAR>redir=>kms<BAR>silent map<BAR>silent imap<BAR>silent cmap<BAR>redir END<BAR>put =kms<CR>

" write
nnoremap \w :write<CR>

" forward yanked text to clip when in remote
if $SSH_CONNECTION != ""
  vnoremap <silent> y y:call RavyClip(@0)<BAR>echo 'Yanked and Sent'<CR>
  nnoremap <silent> \y :call RavyClip(@0)<BAR>echo 'Yanked Sent'<CR>
  vnoremap <silent> \y :call RavyClip(GetVisualSelection())<CR>
endif

" toggle auto zz when scrolling
nnoremap <silent> \z :let &scrolloff=999-&scrolloff<BAR>echo &scrolloff<20?'Auto zz disabled.':'Auto zz enabled.'<CR>

" indent / unindent
nnoremap \<TAB> v>
nnoremap \<S-TAB> v<
vnoremap \<TAB> >gv
vnoremap \<S-TAB> <gv

" insert an empty line without entering insert mode
nmap \<CR> <PLUG>unimpairedBlankDown
nmap \\<CR> <PLUG>unimpairedBlankUp

" FZF
nnoremap a :Ag<SPACE>
nnoremap <silent> b :Buffers<CR>
nnoremap d :call RavyDirectories()<CR>
nnoremap <silent> m :Marks<CR>
nnoremap <silent> e :Lines<CR>
nnoremap <silent> o :Files<CR>
nnoremap <silent> q :Snippets<CR>
nnoremap <silent> t :Filetypes<CR>
nnoremap <silent> v :History<CR>
nnoremap <silent> ; :History:<CR>
nnoremap <silent> / :History/<CR>

" tmux navigator, window move & split
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> h :TmuxNavigateLeft<CR>
nnoremap <silent> j :TmuxNavigateDown<CR>
nnoremap <silent> k :TmuxNavigateUp<CR>
nnoremap <silent> l :TmuxNavigateRight<CR>
nnoremap <silent> p :TmuxNavigatePrevious<CR>
nnoremap <silent> H :call RavyWinMove('h')<CR>
nnoremap <silent> J :call RavyWinMove('j')<CR>
nnoremap <silent> K :call RavyWinMove('k')<CR>
nnoremap <silent> L :call RavyWinMove('l')<CR>
nnoremap <silent> c :close<CR>
nnoremap <silent> C :close<CR>

" key pool
nnoremap f <NOP>
nnoremap g <NOP>
nnoremap i <NOP>
nnoremap r <NOP>
nnoremap u <NOP>
nnoremap w <NOP>
nnoremap x <NOP>
nnoremap y <NOP>
nnoremap z <NOP>
nnoremap  <NOP>
nnoremap \b <NOP>
nnoremap \e <NOP>
nnoremap \g <NOP>
nnoremap \i <NOP>
nnoremap \j <NOP>
nnoremap \k <NOP>
nnoremap \n <NOP>
nnoremap \o <NOP>
nnoremap \r <NOP>
nnoremap \t <NOP>
nnoremap \x <NOP>

" }}

" }}

" Plugin Settings {{

" Tags {{

nnoremap <C-T> :TagbarToggle<CR>

let g:easytags_async=1
let g:easytags_always_enabled=1

" }}

" auto-pairs {{

let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutToggle=''
let g:AutoPairsShortcutBackInsert = '<C-b>'
let g:AutoPairsShortcutFastWrap = '<C-e>'
let g:AutoPairsShortcutJump = ''

nnoremap n :call AutoPairsJump()<CR>

" }}

" neoformat {{

noremap \fm :Neoformat<CR>

" Only msg when there is an error.
let g:neoformat_only_msg_on_error = 1

" Enable alignment
let g:neoformat_basic_format_align = 1

" Enable tab to spaces conversion
let g:neoformat_basic_format_retab = 1

" Let clang-format use Google style.
let g:neoformat_c_clangformat = {
      \ 'exe': 'clang-format',
      \ 'args': ['--style Google'],
      \ 'stdin': 1,
      \ }
let g:neoformat_cpp_clangformat = g:neoformat_c_clangformat
let g:neoformat_objc_clangformat = g:neoformat_c_clangformat
let g:neoformat_proto_clangformat = g:neoformat_c_clangformat
let g:neoformat_java_clangformat = g:neoformat_c_clangformat

" Use clang-format for c, cpp, objc and proto.
let g:neoformat_enabled_c = ['clangformat']
let g:neoformat_enabled_cpp = ['clangformat']
let g:neoformat_enabled_objc = ['clangformat']
let g:neoformat_enabled_proto = ['clangformat']
let g:neoformat_enabled_java = ['clangformat']

" }}

" syntastic {{

let g:syntastic_always_populate_loc_list = 1

" }}

" vim-airline {{

let g:airline_powerline_fonts=1

" }}

" vim-easy-align {{

xmap ga <PLUG>(EasyAlign)
nmap ga <PLUG>(EasyAlign)

" }}

" vim-easyclip {{

let g:EasyClipUsePasteToggleDefaults = 0

nmap <C-J> <PLUG>EasyClipSwapPasteForward
nmap <C-K> <PLUG>EasyClipSwapPasteBackwards

nmap M <Plug>MoveMotionEndOfLinePlug

" }}

" vim-easymotion {{

" use \\ as the prefix
nmap \\ <PLUG>(easymotion-prefix)

" Turn on case insensitive feature
let g:EasyMotion_smartcase = 1

" }}

" vim-gitgutter {{

let g:gitgutter_map_keys = 0

function! GitGutterDiffBase()
  echo "GitGutter diff base: " . g:gitgutter_diff_base
endfunction

nmap \hn <PLUG>GitGutterNextHunk
nmap \hp <PLUG>GitGutterPrevHunk

nmap \hu <PLUG>GitGutterUndoHunk
nmap \hs <PLUG>GitGutterStageHunk
nmap \hv <PLUG>GitGutterPreviewHunk

nnoremap <silent> \hc :call GitGutterDiffBase()<CR>
nnoremap <silent> \hr :let g:gitgutter_diff_base=''<BAR>silent write<BAR>call GitGutterDiffBase()<CR>
nnoremap \hb :let g:gitgutter_diff_base=''<LEFT>
for i in range(0, 9)
  exec 'nmap <silent> \h' . i . ' :let g:gitgutter_diff_base="HEAD~' . i . '"<BAR>silent write<BAR>call GitGutterDiffBase()<CR>'
endfor

" text objects
omap ic <PLUG>GitGutterTextObjectInnerPending
omap ac <PLUG>GitGutterTextObjectOuterPending
xmap ic <PLUG>GitGutterTextObjectInnerVisual
xmap ac <PLUG>GitGutterTextObjectOuterVisual

" }}

" vim-indent-guides {{

let g:indent_guides_auto_colors = 0
let g:indent_guides_start_level = 2

augroup indentguides
  autocmd!
  autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=grey
  autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgrey
augroup END

nnoremap \p :IndentGuidesToggle<CR>

" }}

" vim-peekaboo {{

let g:peekaboo_window = 'vertical leftabove 40new'

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

nnoremap <silent> s :call OpenSessionFZF()<CR>
nnoremap \so :call OpenSessionFZF()<CR>

nnoremap \sn :SaveSession<SPACE>
nnoremap \sd :DeleteSession<SPACE>
nnoremap \ss :SaveSession<CR>
nnoremap \sc :CloseSession<CR>
nnoremap \sv :ViewSession<CR>

nnoremap \sf :echo 'Current Session: ' . xolox#session#find_current_session()<CR>

" }}

" vim-sneak {{

" use case option from search settings
let g:sneak#use_ic_scs = 1

" label mode
let g:sneak#label = 1

" }}

" vim-surround {{

let g:surround_35="#{\r}"      " #
let g:surround_36="$(\r)"      " $

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

" Plugins & Custom Settings {{

call plug#begin('~/.vim/bundle')

Plug 'ConradIrwin/vim-bracketed-paste' " auto paste mode when pasting from terminal
Plug 'PeterRincker/vim-argumentative'  " argument: [, ], to jump & <, >, to shift & a, i, is text-object
Plug 'SirVer/ultisnips'                " snippets manager
Plug 'Valloric/MatchTagAlways'         " always highlight matching markup language tags
Plug 'airblade/vim-gitgutter'          " git: hunks operation indicator
Plug 'ap/vim-css-color'                " show css color in code
Plug 'christoomey/vim-tmux-navigator'  " pane navigate integration with tmux
Plug 'easymotion/vim-easymotion'       " choose from positions which repeated motions would reach
Plug 'google/vim-searchindex'          " search: show match index and total match count
Plug 'honza/vim-snippets'              " snippets
Plug 'ivanov/vim-ipython'              " ipython integration
Plug 'jiangmiao/auto-pairs'            " Insert or delete brackets, parens, quotes in pair
Plug 'jpo/vim-railscasts-theme'        " decent colorscheme
Plug 'junegunn/fzf'                    " fzf integration
Plug 'junegunn/fzf.vim'                " provide utility commands to fzf in a list of certain targets
Plug 'junegunn/vim-easy-align'         " ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-peekaboo'           " extends \", @, i:<C-R> to list the contents registers
Plug 'justinmk/vim-sneak'              " s: motion to match 2 characters
Plug 'metakirby5/codi.vim'             " Interactive scratchpad
Plug 'moll/vim-bbye'                   " sane Bdelete
Plug 'nathanaelkane/vim-indent-guides' " visually displaying indent levels
Plug 'ntpeters/vim-better-whitespace'  " highlight trailing blanks and provide StripWhitespace function
Plug 'sbdchd/neoformat'                " Auto format
Plug 'scrooloose/syntastic'            " check code syntax
Plug 'sheerun/vim-polyglot'            " a set of filetype plugins
Plug 'svermeulen/vim-easyclip'         " better clipboard of vim
Plug 'terryma/vim-expand-region'       " +, - to expand and shrink selection
Plug 'terryma/vim-multiple-cursors'    " multiple cursors and multiple modifications
Plug 'tpope/vim-commentary'            " gc to comment codes
Plug 'tpope/vim-repeat'                " `.` supports to repeat mapped key sequence
Plug 'tpope/vim-surround'              " `s`: manipulate surrounded symbols / texts
Plug 'tpope/vim-unimpaired'            " a bunch of useful [, ] key bindings
Plug 'vim-airline/vim-airline'         " status line with powerline fonts
Plug 'vim-scripts/vim-scroll-position' " simulated scroll bar using sign column
Plug 'xolox/vim-misc'                  " vim plugin util
Plug 'xolox/vim-session'               " session manager

if executable('ctags')
  Plug 'xolox/vim-easytags'            " auto generate tags
  Plug 'majutsushi/tagbar'             " tag explorer
endif

if filereadable($RAVY_CUSTOM_HOME."/vimrc")
  source $RAVY_CUSTOM_HOME/vimrc
endif

call plug#end()

if !exists('g:colors_name')
  colorscheme railscasts
endif

" }}
