" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker:
" }}

" Settings {{

" make directory if necessary
if !isdirectory(expand("~/.vim/tmp")) || !isdirectory(expand("~/.vim/bundle"))
  call system("mkdir -p ~/.vim/tmp ~/.vim/bundle")
end

" General
set directory=~/.vim/tmp//,. swapfile
set backupdir=~/.vim/tmp//,. nobackup writebackup
set undodir=~/.vim/tmp//,. undofile undolevels=1000 undoreload=10000
set wildignore+=*.png,*.jpg,*.gif,*.ico,*.mp3,*.mp4,*.avi,*.mkv,*.o,*.obj,*.pyc,*.swf,*.fla,*.git*,*.hg*,*.svn*,*sass-cache*,log/**,tmp/**,*~,*~orig,*.DS_Store,tags,.tags,.tags_sorted_by_file,node_modules
set encoding=utf-8 termencoding=utf-8 fileencoding=utf-8 fileencodings=utf-8,big5,gbk,euc-jp,euc-kr,iso8859-1,utf-16le,latin1
set formatoptions=nmMcroql
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
set tabstop=8 softtabstop=2 shiftwidth=2 expandtab smarttab
set copyindent smartindent nocindent
set ignorecase smartcase
set hlsearch incsearch
set modeline modelines=9
set history=10000
set shell=bash
set mouse=a
set iskeyword+=-
set updatetime=100
set notimeout                    " no timeout for key map sequence
set splitright splitbelow        " split window: vertical to the right and horizontal to the below
set hidden                       " hidden buffers
set nospell                      " no spell check
set nobomb                       " no Byte Order Mark
set synmaxcol=4096               " max columnlength for syntax parsing
set switchbuf=useopen            " when switching to a buffer, jump to a window with it opened
set nostartofline                " does not move the cursor to start of line for some commands
set scrolloff=3 scrolljump=1     " 3 lines away from margins to scroll 1 line
set sidescrolloff=8 sidescroll=2 " 8 columns away from margins to scroll 2 column

" UI
set number numberwidth=4
set nofoldenable foldmethod=indent foldlevel=0 foldnestmax=3
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.
set showmatch matchpairs+=<:>
set viewoptions=folds,options,cursor,unix,slash
set title titlestring=!%t:%l%(\ %m%r%h%w%)
set textwidth=80
set winwidth=79 winheight=5 winminheight=5
set linebreak breakindent showbreak=>>
set background=dark
set noshowmode
set showcmd
set lazyredraw
set nocursorline
set visualbell noerrorbells
set wildmenu wildmode=list:longest,full " completions: list matches, then longest common part, then all.
set wrap whichwrap=b,s,h,l,<,>,[,]      " Backspace and cursor keys wrap too
set showtabline=1                       " show tab when multi tabs exist
set colorcolumn=+1                      " highlight over width boundary
set virtualedit=onemore                 " cursor beyond last character
set shortmess+=filmnrxoOtTI             " Abbreviation of file messages: try <C-G>

" make cursor a non-blinking vertical bar in insert mode and a non-blinking block elsewhere
let &t_ti.="\e[2 q"
let &t_te.="\e[2 q"
let &t_SI="\e[6 q"
let &t_EI="\e[2 q"

" title string reporting
if $TMUX != ""
  " tmux pane title
  set t_ts=]2 t_fs=\\
elseif $ITERM_SESSION_ID != ""
  " iterm window title
  set t_ts=]; t_fs=
endif

scriptencoding utf-8
filetype plugin indent on

" }}

" Autocmds {{

augroup BufferEdit
  autocmd!

  autocmd BufWritePre * StripWhitespace

  " restore cursor position when read a buffer
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif

  " set the cursor position to the beginning when editing commit message
  autocmd BufReadPost COMMIT_EDITMSG normal gg0

  " highlight cursorline only in insert mode
  autocmd InsertEnter * set cursorline
  autocmd InsertLeave * set nocursorline
augroup END

if $SSH_CONNECTION != ""
  augroup RemoteClip
    autocmd!

    " forward remote yanked text
    autocmd TextYankPost * if v:event.operator ==# 'y' | call SendViaOSC52(getreg('"')) | endif
  augroup END
  set clipboard=
else
  " access system clipboard if local
  set clipboard=unnamed
endif

" }}

" Functions {{

" Get visual selection text
function! GetVisualSelection()
  let [line_start, column_start] = getpos("'<")[1:2]
  let [line_end, column_end] = getpos("'>")[1:2]
  let lines = getline(line_start, line_end)
  if len(lines) == 0
    return ''
  endif
  let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][column_start - 1:]
  return join(lines, "\n")
endfunction

" send text to remote or system clipboard
function! SendViaOSC52(text)
  silent call system('osc52.sh >/dev/tty', a:text)
endfunction

" open a link remotely
function! RavyRemoteOpenLink(url)
  let t:url = substitute(a:url, "[\x0d\x0a].*", "", "")
  let t:url = substitute(t:url, '^\s\+', "", "")
  let t:url = (t:url =~ '.*://' ? '' : 'https://www.google.com/search?q=') . t:url
  call SendViaOSC52("RAVY\x0dopen\x0d" . t:url)
endfunction

" fzf to select a directory to change to
function! FZFDirectories()
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

function! s:AltMapKey(key)
  return has('nvim')?  "<A-". a:key . ">" : "<ESC>". a:key
endfun

" repl-visual-no-reg-overwrite.vim {{

function! RestoreRegister()
  if &clipboard == 'unnamed'
    call setreg('*', s:restore_reg)
  elseif &clipboard == 'unnamedplus'
    call setreg('+', s:restore_reg)
  else
    call setreg('"', s:restore_reg)
  endif
  return ''
endfunction

function! s:Repl()
    let s:restore_reg = getreg('"')
    return "p@=RestoreRegister()\<cr>"
endfunction

function! s:ReplSelect()
    echo "Register to paste over selection? (<cr> => default register: ".strtrans(getreg('"')).")"
    let c = nr2char(getchar())
    let reg = c =~ '^[0-9a-z:.%#/*+~]$'
                \ ? '"'.c
                \ : ''
    return "\<C-G>".reg.s:Repl()
endfunction

" This supports "rp that permits to replace the visual selection with the
" contents of @r
xnoremap <silent> <expr> p <sid>Repl()

" Mappings on <s-insert>, that'll also work in select mode!
xnoremap <silent> <expr> <S-Insert> <sid>Repl()
snoremap <silent> <expr> <S-Insert> <sid>ReplSelect()

" }}

" }}

" Keys {{

" basic key remap {{

" scroll the view port faster
nnoremap <C-E> 3<C-E>
nnoremap <C-Y> 3<C-Y>

" 0 go to first non blank, ^ go to the very beginning
nnoremap 0 ^
nnoremap ^ 0

" }}

" imap / cmap {{

" <CR>: close popup and save indent.
inoremap <expr><CR> pumvisible() ? "\<C-Y>" : "\<CR>"

" C-J / C-K => C-N / C-P
inoremap <C-J> <C-N>
inoremap <C-K> <C-P>

" C-C => ESC
inoremap <C-C> <C-[>

" %% to insert current opened buffer's directory path in command mode
cnoremap <expr> %% getcmdtype() == ':' ? expand('%:h').'/' : '%%'

" w!! to force write to a RO file in command mode
cnoremap w!! w !sudo tee % >/dev/null

" C-P, C-N to prefix search in history in command mode
cnoremap <C-P> <UP>
cnoremap <C-N> <DOWN>
cnoremap <UP> <C-P>
cnoremap <DOWN> <C-N>

" }}

" nmap / vmap {{

" 'Cut' motion
nnoremap m d
xnoremap m d
nnoremap mm dd
nnoremap M D

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap gB :bnext<CR>

" similar to gf, open file path under cursor, but in a split window in right
nnoremap gw :exec("vsplit ".expand("<cfile>"))<CR>

" Visually select the text that was last edited/pasted
nnoremap gV `[v`]

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

" close current buffer
nnoremap \c :Bdelete!<CR>

" diff
nnoremap <silent> \de :bdelete!<BAR>diffoff<CR>
nnoremap <silent> \dl :diffget 1<BAR>diffupdate<CR>
nnoremap <silent> \db :diffget 2<BAR>diffupdate<CR>
nnoremap <silent> \dr :diffget 3<BAR>diffupdate<CR>

" current working directory
" print current working directory and path of current buffer
nnoremap \ff :echo getcwd().' > '. expand('%')<CR>
" change current working directory
nnoremap \f. :lcd ..<BAR>pwd<CR>
nnoremap \fh :lcd %:p:h<BAR>pwd<CR>
nnoremap \fe :lcd<SPACE>

" \h*: GitGutter

nnoremap <silent> \l :call RavyRemoteOpenLink(getreg('"'))<CR>
vnoremap <silent> \l :call RavyRemoteOpenLink(GetVisualSelection())<CR>

" new buffer
nnoremap \n :enew<CR>

" toggle quickfix window
nnoremap <silent> \q :exec exists('g:qfwin')?'cclose<BAR>unlet g:qfwin':'copen<BAR>let g:qfwin=bufnr("$")'<CR>

" substitute
vnoremap \s :s/
nnoremap \s :%s/

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<BAR>echo &foldenable?'Fold enabled.':'Fold disabled.'<CR>

" edit / reload vimrc
nnoremap \ve :edit $MYVIMRC<CR>
nnoremap \vs :source $MYVIMRC<CR>

" print key maps in a new buffer
nnoremap \vm :enew<BAR>redir=>kms<BAR>silent map<BAR>silent map!<BAR>redir END<BAR>put =kms<CR>

" Install & Update plugins
nnoremap \vu :PlugUpdate<CR>

" Clean plugins
nnoremap \vc :PlugClean!<CR>

" write
nnoremap \w :write<CR>

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
exec 'nnoremap          ' . s:AltMapKey('a') . ' :Ag<SPACE>'
exec 'nnoremap <silent> ' . s:AltMapKey('d') . ' :call FZFDirectories()<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('b') . ' :Buffers<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('m') . ' :Marks<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('e') . ' :Lines<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('o') . ' :Files %:p:h<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('f') . ' :Files<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('q') . ' :Snippets<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('t') . ' :Filetypes<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('v') . ' :History<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey(';') . ' :History:<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('/') . ' :History/<CR>'

" tmux navigator, window move & split
let g:tmux_navigator_no_mappings = 1
exec 'nnoremap <silent> ' . s:AltMapKey('h') . ' :TmuxNavigateLeft<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('j') . ' :TmuxNavigateDown<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('k') . ' :TmuxNavigateUp<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('l') . ' :TmuxNavigateRight<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('p') . ' :TmuxNavigatePrevious<CR>'
exec 'nnoremap <silent> ' . s:AltMapKey('c') . ' :close<CR>'

" Show unicode names
exec 'nnoremap <silent> ' . s:AltMapKey('u') . ' :UnicodeName<CR>'

" key pool
exec 'nnoremap          ' . s:AltMapKey('g') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('i') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('n') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('r') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('w') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('x') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('y') . ' <NOP>'
exec 'nnoremap          ' . s:AltMapKey('z') . ' <NOP>'

" nnoremap <ESC><ESC> <NOP>

nnoremap \b <NOP>
nnoremap \e <NOP>
nnoremap \g <NOP>
nnoremap \i <NOP>
nnoremap \j <NOP>
nnoremap \k <NOP>
nnoremap \m <NOP>
nnoremap \o <NOP>
nnoremap \p <NOP>
nnoremap \r <NOP>
nnoremap \t <NOP>
nnoremap \x <NOP>

" }}

" }}

" Plugin Settings {{

" tagbar {{

nnoremap <C-T> :TagbarToggle<CR>

" }}

" auto-pairs {{

let g:AutoPairsFlyMode = 0
let g:AutoPairsShortcutToggle=''
let g:AutoPairsShortcutFastWrap = ''
let g:AutoPairsShortcutJump = ''

" }}

" rainbow {{

let g:rainbow_active = 1

" }}

" syntastic {{

let g:syntastic_always_populate_loc_list = 1

" }}

" vim-airline {{

let g:airline_powerline_fonts=1

" }}

" vim-cool {{

let g:CoolTotalMatches = 1

" }}

" vim-easy-align {{

xmap ga <PLUG>(EasyAlign)
nmap ga <PLUG>(EasyAlign)

" }}

" vim-yoink {{

nmap <C-J> <PLUG>(YoinkPostPasteSwapBack)
nmap <C-K> <PLUG>(YoinkPostPasteSwapForward)

nmap p <PLUG>(YoinkPaste_p)
nmap P <PLUG>(YoinkPaste_P)

let g:yoinkSyncNumberedRegisters = 0
let g:yoinkIncludeDeleteOperations = 1

" }}

" vim-gitgutter {{

let g:gitgutter_map_keys = 0

function! GitGutterDiffBase()
  GitGutter
  echo "GitGutter diff base: " . g:gitgutter_diff_base
endfunction

nmap \hn <PLUG>(GitGutterNextHunk)
nmap \hp <PLUG>(GitGutterPrevHunk)

nmap \hu <PLUG>(GitGutterUndoHunk)
nmap \hs <PLUG>(GitGutterStageHunk)
nmap \hv <PLUG>(GitGutterPreviewHunk)

nnoremap <silent> \hl :GitGutterLineHighlightsToggle<CR>
nnoremap <silent> \hc :call GitGutterDiffBase()<CR>
nnoremap <silent> \hr :let g:gitgutter_diff_base=''<BAR>call GitGutterDiffBase()<CR>
nnoremap \hb :let g:gitgutter_diff_base=''<LEFT>
for i in range(0, 9)
  exec 'nnoremap <silent> \h' . i . ' :let g:gitgutter_diff_base="HEAD~' . i . '"<BAR>call GitGutterDiffBase()<CR>'
endfor

" text objects
omap ic <PLUG>(GitGutterTextObjectInnerPending)
omap ac <PLUG>(GitGutterTextObjectOuterPending)
xmap ic <PLUG>(GitGutterTextObjectInnerVisual)
xmap ac <PLUG>(GitGutterTextObjectOuterVisual)

" }}

" vim-indent-guides {{

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level = 3
let g:indent_guides_auto_colors = 0

" }}

" vim-peekaboo {{

let g:peekaboo_window = 'vertical leftabove 40new'

" }}

" vim-polyglot {{

let g:polyglot_disabled = ['csv', 'jsx']

" }}

" vim-prettier {{

noremap \fm :Prettier<CR>

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

" vim-scroll-position {{

let g:scroll_position_marker         = '❯'
let g:scroll_position_visual_begin   = '-'
let g:scroll_position_visual_middle  = '|'
let g:scroll_position_visual_end     = '-'
let g:scroll_position_visual_overlap = '❮❯'

" }}

" }}

" Plugins & Custom Settings {{

call plug#begin(expand('~/.vim/bundle'))

let s:custom_vimrc = expand('<sfile>:p:h') . '/' . 'custom/vimrc'
if filereadable(s:custom_vimrc)
  exec 'source ' . s:custom_vimrc
endif

Plug 'ConradIrwin/vim-bracketed-paste' " auto paste mode when pasting from terminal
Plug 'PeterRincker/vim-argumentative'  " argument: jump: '[,' '],'; shift: '<,' '>,'; text-object: 'a,' 'i,'
Plug 'SirVer/ultisnips'                " snippets engine
Plug 'airblade/vim-gitgutter'          " git: hunks operation indicator
Plug 'airblade/vim-rooter'             " set proper working directory
Plug 'andymass/vim-matchup'            " even better % navigate and highlight matching words
Plug 'ap/vim-css-color'                " show css color in code
Plug 'chrisbra/unicode.vim'            " Search unicode
Plug 'christoomey/vim-tmux-navigator'  " pane navigate integration with tmux
Plug 'honza/vim-snippets'              " snippets
Plug 'jiangmiao/auto-pairs'            " Insert or delete brackets, parens, quotes in pair
Plug 'junegunn/fzf'                    " fzf integration
Plug 'junegunn/fzf.vim'                " provide utility commands to fzf in a list of certain targets
Plug 'junegunn/vim-easy-align'         " ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-peekaboo'           " list the content of registers when \", @ in normal mode and <C-R> in insert mode
Plug 'justinmk/vim-sneak'              " s: motion to match 2 characters
Plug 'luochen1990/rainbow'             " Decorate brackets, parens and pairs with pairing colors
Plug 'majutsushi/tagbar'               " tag explorer
Plug 'moll/vim-bbye'                   " sane Bdelete
Plug 'mushanyoung/vim-windflower'      " theme
Plug 'nathanaelkane/vim-indent-guides' " visually displaying indent levels
Plug 'ntpeters/vim-better-whitespace'  " highlight trailing blanks and provide StripWhitespace function
Plug 'romainl/vim-cool'                " show match index during search and cancel highlight afterwards
Plug 'sheerun/vim-polyglot'            " a set of filetype plugins
Plug 'svermeulen/vim-cutlass'          " plugin that adds a 'cut' operation separate from 'delete'
Plug 'svermeulen/vim-yoink'            " maintains a yank history to cycle between when pasting
Plug 'terryma/vim-expand-region'       " +, - to expand and shrink selection
Plug 'terryma/vim-multiple-cursors'    " multiple cursors and multiple modifications
Plug 'tpope/vim-abolish'               " deal with multiple variants of a word
Plug 'tpope/vim-commentary'            " gc to comment codes
Plug 'tpope/vim-repeat'                " `.` supports to repeat mapped key sequence
Plug 'tpope/vim-rsi'                   " Readline style insertion
Plug 'tpope/vim-sensible'              " default settings
Plug 'tpope/vim-speeddating'           " use CTRL-A/CTRL-X to increment dates, times, and more
Plug 'tpope/vim-surround'              " `s`: manipulate surrounded symbols / texts
Plug 'tpope/vim-unimpaired'            " a bunch of useful [, ] key bindings
Plug 'vim-airline/vim-airline'         " status line with powerline fonts
Plug 'vim-scripts/vim-scroll-position' " simulated scroll bar using sign column
Plug 'vim-syntastic/syntastic'         " check code syntax

if !exists('g:disable_prettier')
  " auto format by prettier
  Plug 'prettier/vim-prettier', {
    \ 'do': 'npm install',
    \ 'branch': 'release/1.x',
    \ 'for': [ 'javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'lua', 'php', 'python', 'ruby', 'html', 'swift' ] }
endif

if !exists('g:disable_ctags') && executable('ctags')
  Plug 'ludovicchabant/vim-gutentags'
endif

call plug#end()

if !exists('g:colors_name')
  colorscheme windflower
endif

" }}
