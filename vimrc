" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker filetype=vim:
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
set formatoptions=nmMcroql
set iskeyword+=-
set updatetime=100
set clipboard=unnamed          " access system clipboard
set notimeout                  " no timeout for key map sequence
set splitright splitbelow      " split window: vertical to the right and horizontal to the below
set hidden                     " hidden buffers
set nospell                    " no spell check
set nobomb                     " no Byte Order Mark
set synmaxcol=4096             " max columnlength for syntax parsing
set switchbuf=useopen          " when switching to a buffer, jump to a window with it opened
set nostartofline              " does not move the cursor to start of line for some commands

" UI
set number numberwidth=4
set nofoldenable foldmethod=indent foldlevel=0 foldnestmax=3
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.
set showmatch matchpairs+=<:>
set viewoptions=folds,options,cursor,unix,slash
set title titlestring=#%t%(\ %a%)%(\ %r%)%(\ %m%)
set linebreak
set background=dark
set noshowmode
set showcmd
set lazyredraw
set cursorline
set textwidth=80
set visualbell noerrorbells
set wildmenu wildmode=list:longest,full " completions: list matches, then longest common part, then all.
set wrap whichwrap=b,s,h,l,<,>,[,]      " Backspace and cursor keys wrap too
set showtabline=1                       " show tab when multi tabs exist
set virtualedit=onemore                 " cursor beyond last character
set colorcolumn=+1                      " highlight over width boundary
set scrolloff=3 scrolljump=1            " 3 lines away from margins to scroll 1 line
set sidescrolloff=10 sidescroll=1       " 10 columns away from margins to scroll 1 column
set shortmess+=filmnrxoOtTI             " Abbreviation of file messages: try <C-G>
set winwidth=79 winheight=5 winminheight=5

if &term =~ "screen*" | set t_ts=k t_fs=\ | endif " escape string for window name of screen
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
function! RavyClip(text)
  silent call system('pbcopy >/dev/tty', a:text)
endfunction

" open a link remotely
function! RavyOpenLink(url)
  let t:url = substitute(a:url, "[\x0d\x0a].*", "", "")
  let t:url = substitute(t:url, '^\s\+', "", "")
  let t:url = (t:url =~ '.*://' ? '' : 'https://www.google.com/search?q=') . t:url
  call RavyClip("RAVY\x0dopen\x0d" . t:url)
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

" fzf to select a directory to change to
function! s:FZFDirectories()
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

" repl-visual-no-reg-overwrite.vim {{

function! RestoreRegister()
  if &clipboard == 'unnamed'
    let @* = s:restore_reg
  elseif &clipboard == 'unnamedplus'
    let @+ = s:restore_reg
  else
    let @" = s:restore_reg
  endif
  return ''
endfunction

function! s:Repl()
    let s:restore_reg = @"
    return "p@=RestoreRegister()\<cr>"
endfunction

function! s:ReplSelect()
    echo "Register to paste over selection? (<cr> => default register: ".strtrans(@").")"
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

" C-J / C-J map to C-N / C-P
inoremap <C-J> <C-N>
inoremap <C-K> <C-P>

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
nnoremap gw :let mycurf=expand("<cfile>")<BAR>exec("vsplit ".mycurf)<CR>

" Visually select the text that was last edited/pasted
noremap gV `[v`]

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

nnoremap <silent> \l :call RavyOpenLink(@")<BAR>echo 'Link Sent'<CR>
vnoremap <silent> \l :call RavyOpenLink(GetVisualSelection())<CR>

" toggle mouse
nnoremap <silent> \m :exec &mouse!=''?"set mouse=<BAR>echo 'Mouse Disabled.'":"set mouse=a<BAR>echo 'Mouse Enabled.'"<CR>

" toggle quickfix window
nnoremap <silent> \q :exec exists('g:qfwin')?'cclose<BAR>unlet g:qfwin':'copen<BAR>let g:qfwin=bufnr("$")'<CR>

" toggle foldenable
nnoremap <silent> \u :set invfoldenable<BAR>echo &foldenable?'Fold enabled.':'Fold disabled.'<CR>

" edit / reload vimrc
nnoremap \ve :edit $MYVIMRC<CR>
nnoremap \vs :source $MYVIMRC<CR>

" print key maps in a new buffer
nnoremap \vm :enew<BAR>redir=>kms<BAR>silent map<BAR>silent imap<BAR>silent cmap<BAR>redir END<BAR>put =kms<CR>

" Install & Update plugins
nnoremap \vu :PlugUpdate<CR>

" write
nnoremap \w :write<CR>

" forward yanked text to clip when in remote
if $SSH_CONNECTION != ""
  vnoremap <silent> y y:call RavyClip(@")<BAR>echo 'Yanked and Sent'<CR>
  nnoremap <silent> \yy :call RavyClip(@")<BAR>echo 'Yanked Sent'<CR>
  vnoremap <silent> \yy :call RavyClip(GetVisualSelection())<CR>
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
nnoremap <silent> <expr> d <sid>FZFDirectories()
nnoremap <silent> b :Buffers<CR>
nnoremap <silent> m :Marks<CR>
nnoremap <silent> e :Lines<CR>
nnoremap <silent> o :Files %:p:h<CR>
nnoremap <silent> O :Files<CR>
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
nnoremap \p <NOP>
nnoremap \r <NOP>
nnoremap \s <NOP>
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

" vim-bracketed-paste {{

let g:bracketed_paste_tmux_wrap = 0

" }}

" vim-cpp-enhanced-highlight {{

let g:cpp_class_scope_highlight = 1
let g:cpp_experimental_template_highlight = 1

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

" vim-easymotion {{

" use \\ as the prefix
nmap \\ <PLUG>(easymotion-prefix)

" Turn on case insensitive feature
let g:EasyMotion_smartcase = 1

" }}

" vim-gitgutter {{

let g:gitgutter_map_keys = 0

function! s:GitGutterDiffBase()
  GitGutter
  echo "GitGutter diff base: " . g:gitgutter_diff_base
endfunction

nmap \hn <PLUG>GitGutterNextHunk
nmap \hp <PLUG>GitGutterPrevHunk

nmap \hu <PLUG>GitGutterUndoHunk
nmap \hs <PLUG>GitGutterStageHunk
nmap \hv <PLUG>GitGutterPreviewHunk

nnoremap <silent> \hl :GitGutterLineHighlightsToggle<CR>

nnoremap <silent> <expr> \hc <sid>GitGutterDiffBase()
nnoremap <silent> \hr :let g:gitgutter_diff_base=''<BAR>call GitGutterDiffBase()<CR>
nnoremap \hb :let g:gitgutter_diff_base=''<LEFT>
for i in range(0, 9)
  exec 'nnoremap <silent> \h' . i . ' :let g:gitgutter_diff_base="HEAD~' . i . '"<BAR>call GitGutterDiffBase()<CR>'
endfor

" text objects
omap ic <PLUG>GitGutterTextObjectInnerPending
omap ac <PLUG>GitGutterTextObjectOuterPending
xmap ic <PLUG>GitGutterTextObjectInnerVisual
xmap ac <PLUG>GitGutterTextObjectOuterVisual

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

" }}

" Plugins & Custom Settings {{

call plug#begin('~/.vim/bundle')

if filereadable($RAVY_CUSTOM_HOME."/vimrc")
  source $RAVY_CUSTOM_HOME/vimrc
endif

Plug 'ConradIrwin/vim-bracketed-paste' " auto paste mode when pasting from terminal
Plug 'PeterRincker/vim-argumentative'  " argument: jump: '[,' '],'; shift: '<,' '>,'; text-object: 'a,' 'i,'
Plug 'SirVer/ultisnips'                " snippets engine
Plug 'honza/vim-snippets'              " snippets
Plug 'airblade/vim-gitgutter'          " git: hunks operation indicator
Plug 'andymass/vim-matchup'            " even better % navigate and highlight matching words
Plug 'ap/vim-css-color'                " show css color in code
Plug 'chrisbra/unicode.vim'            " Search unicode
Plug 'christoomey/vim-tmux-navigator'  " pane navigate integration with tmux
Plug 'easymotion/vim-easymotion'       " choose from positions which repeated motions would reach
Plug 'henrik/vim-indexed-search'       " search: show match index and total match count
Plug 'jiangmiao/auto-pairs'            " Insert or delete brackets, parens, quotes in pair
Plug 'luochen1990/rainbow'             " Decorate brackets, parens and pairs with pairing colors
Plug 'junegunn/fzf'                    " fzf integration
Plug 'junegunn/fzf.vim'                " provide utility commands to fzf in a list of certain targets
Plug 'junegunn/vim-easy-align'         " ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-peekaboo'           " list the content of registers when \", @ in normal mode and <C-R> in insert mode
Plug 'justinmk/vim-sneak'              " s: motion to match 2 characters
Plug 'moll/vim-bbye'                   " sane Bdelete
Plug 'mushanyoung/vim-windflower'      " theme
Plug 'nathanaelkane/vim-indent-guides' " visually displaying indent levels
Plug 'ntpeters/vim-better-whitespace'  " highlight trailing blanks and provide StripWhitespace function
Plug 'scrooloose/syntastic'            " check code syntax
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
Plug 'majutsushi/tagbar'               " tag explorer
Plug 'prettier/vim-prettier'           " auto format by prettier
Plug 'airblade/vim-rooter'             " set proper working directory

if !exists('g:ravy_disable_ctags') && executable('ctags')
  Plug 'ludovicchabant/vim-gutentags'
endif

call plug#end()

if !exists('g:colors_name')
  colorscheme windflower
endif

" }}
