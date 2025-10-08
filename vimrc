" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker:
" }}

" Settings {{

" Neovim
set shadafile=~/.config/nvim/main.shada

" General
set directory=~/.config/nvim/swap// swapfile
set backupdir=~/.config/nvim/backup// nobackup writebackup
set undodir=~/.config/nvim/undo// undofile undolevels=1000 undoreload=10000
set wildignore+=*.png,*.jpg,*.gif,*.ico,*.mp3,*.mp4,*.avi,*.mkv,*.o,*.obj,*.pyc,*.swf,*.fla,*.git*,*.hg*,*.svn,log/**,tmp/**,*~,*~orig,*.DS_Store,tags,.tags,.tags_sorted_by_file,node_modules
set encoding=utf-8 fileencoding=utf-8 fileencodings=ucs-bom,utf-8,default,latin1,utf-16le,big5,gbk,euc-jp,euc-kr,iso8859-1
set formatoptions=nmMcroql
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
set tabstop=8
set softtabstop=4 shiftwidth=4 expandtab smarttab
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

" Register system clipboard
if has('clipboard')
  set clipboard+=unnamed,unnamedplus
endif

" UI
set number numberwidth=4
set nofoldenable foldmethod=indent foldlevel=0 foldnestmax=3
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.
set showmatch matchpairs+=<:>
set viewoptions=folds,options,cursor,unix,slash
set title titlestring=✏️\ \ %t:%l%(\ %m%r%h%w%)
set textwidth=120
set winwidth=79 winheight=5 winminheight=5
set linebreak breakindent showbreak=>>
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

" Bracketed Paste Mode:
" [Vim Control Sequence Examples](https://web.archive.org/web/20221005051612/https://ttssh2.osdn.jp/manual/4/en/usage/tips/vim.html)
if &term =~? 'tmux' || &term =~? 'screen'
  let &t_BE="\e[?2004h"
  let &t_BD="\e[?2004l"
  let &t_PS="\e[200~"
  let &t_PE="\e[201~"
endif

" title string reporting
if !empty($ITERM_SESSION_ID) && empty($TMUX)
  " iterm window title
  set t_ts=]; t_fs=
endif

scriptencoding utf-8

" }}

" Autocmds {{

augroup BufferEdit
  autocmd!

  " restore cursor position when read a buffer
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif

  " set the cursor position to the beginning when editing commit message
  autocmd BufReadPost COMMIT_EDITMSG normal gg0

  " highlight cursorline only in insert mode
  autocmd InsertEnter * set cursorline
  autocmd InsertLeave * set nocursorline
augroup END

" }}

" Functions {{

" open a link remotely
" function! RavyRemoteOpenLink(url)
"   let t:url = substitute(a:url, "[\x0d\x0a].*", "", "")
"   let t:url = substitute(t:url, '^\s\+', "", "")
"   let t:url = (t:url =~ '.*://' ? '' : 'https://www.google.com/search?q=') . t:url
"   call OSCYank("RAVY\x0dopen\x0d" . t:url)
" endfunction
" nnoremap <silent> \l :call RavyRemoteOpenLink(getreg('"'))<CR>

function! s:osc52_yank() abort
  if v:event.operator ==# 'y' && v:event.regname ==# ''
    lua require('osc52').copy_register('"')
  endif
endfunction

augroup osc52
  autocmd!
  autocmd TextYankPost * call s:osc52_yank()
augroup END

function! ExtractMatches(pattern)
  " Save current buffer number
  let curbuf = bufnr('%')

  " Collect matches
  let matches = []
  for lnum in range(1, line('$'))
    let line = getbufline(curbuf, lnum)[0]

    let start = 0
    while 1
      let m = matchstrpos(line, a:pattern, start)
      if m[1] == -1
        break
      endif
      call add(matches, m[0])
      let start = m[2]
    endwhile
  endfor

  " Open results in a new buffer
  new
  call setline(1, matches)
endfunction

command! -nargs=1 ExtractMatches call ExtractMatches(<q-args>)

" fzf to select a directory to change to
function! FZFDirectories()
  function! DirectorySink(line)
    exec 'cd ' . a:line
    pwd
  endfunction

  return fzf#run(fzf#wrap({
        \ 'source': '(echo ./..; find . -type d -not -path "*/\.*" | sed 1d) | cut -b3-',
        \ 'sink': function('DirectorySink'),
        \ 'options': ['+m', '--prompt', 'Dir> ', '--preview', 'eza --tree --color=always {}'],
        \ 'down': '~40%'}))
endfunction

function! s:AltMapKey(key)
  return has('nvim')?  '<A-'. a:key . '>' : '<ESC>'. a:key
endfun

" }}

" Obsidian Vimrc compatible settings {{

" exit insert mode
imap jj <Esc>

" scroll the view port faster
nnoremap <C-E> 3<C-E>
nnoremap <C-Y> 3<C-Y>

" H and L go to beginning/end of line
nnoremap H ^
nnoremap L $

" 'Cut' motion
nnoremap m d
vnoremap m d
nnoremap mm dd
nnoremap M D

" paste in visual mode does not overwrite the register
vnoremap p "_dP

" Y to copy to the end of the line
nnoremap Y y$

" repalce texts
vnoremap <Space>/ :s/
nnoremap <Space>/ :%s/

" select ALL the buffer
nnoremap <Space>a ggVG

" write
nnoremap <Space>w :write<CR>

" }}

" Keys {{

" imap / cmap {{

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

" readline style insert mode keys
inoremap <C-A> <C-O>^
cnoremap <C-A> <Home>

inoremap <expr> <C-E> col('.')>strlen(getline('.'))<bar><bar>pumvisible()?"\<Lt>C-E>":"\<Lt>End>"

" }}

" nmap / vmap {{

" cycle in buffers
nnoremap gb :bprevious<CR>
nnoremap gB :bnext<CR>

" similar to gf, open file path under cursor, but in a split window in right
nnoremap gw :exec("vsplit ".expand("<cfile>"))<CR>

" Visually select the text that was last edited/pasted
nnoremap gV `[v`]

" map leader key to >
let g:mapleader = '>'

" search & substitute very magically
nnoremap / /\v
vnoremap / /\v

" close current buffer
nnoremap <Space>x :Sayonara<CR>

" diff
nnoremap <silent> <Space>de :bdelete!<BAR>diffoff<CR>
nnoremap <silent> <Space>dl :diffget 1<BAR>diffupdate<CR>
nnoremap <silent> <Space>db :diffget 2<BAR>diffupdate<CR>
nnoremap <silent> <Space>dr :diffget 3<BAR>diffupdate<CR>

" current working directory
" print current working directory and path of current buffer
nnoremap <Space>ff :echo getcwd().' > '. expand('%')<CR>
" change current working directory
nnoremap <Space>f. :lcd ..<BAR>pwd<CR>
nnoremap <Space>fh :lcd %:p:h<BAR>pwd<CR>
nnoremap <Space>fe :lcd<Space>

" \h*: GitGutter

" new buffer
nnoremap <Space>n :enew<CR>

" toggle quickfix window
nnoremap <silent> <Space>q :exec exists('g:qfwin')?'cclose<BAR>unlet g:qfwin':'copen<BAR>let g:qfwin=bufnr("$")'<CR>

" toggle foldenable
nnoremap <silent> <Space>u :set invfoldenable<BAR>echo &foldenable?'Fold enabled.':'Fold disabled.'<CR>

" edit / reload vimrc
nnoremap <Space>ve :edit $MYVIMRC<CR>
nnoremap <Space>vs :source $MYVIMRC<CR>

" print key maps in a new buffer
nnoremap <Space>vm :enew<BAR>redir=>kms<BAR>silent map<BAR>silent map!<BAR>redir END<BAR>put =kms<CR>

" Install & Update plugins
nnoremap <Space>vu :PlugUpdate<CR>

" Clean plugins
nnoremap <Space>vc :PlugClean!<CR>

" execute
nnoremap <Space>r :!"%:p"<CR>

" toggle auto zz when scrolling
nnoremap <silent> <Space>z :let &scrolloff=999-&scrolloff<BAR>echo &scrolloff<20?'Auto zz disabled.':'Auto zz enabled.'<CR>

" indent / unindent
nnoremap <TAB> v>
nnoremap <S-TAB> v<
vnoremap <TAB> >gv
vnoremap <S-TAB> <gv

" insert an empty line without entering insert mode
nmap <Space><CR> <PLUG>unimpairedBlankDown
nmap <Space><Space> <PLUG>unimpairedBlankUp

" FZF
exec 'nnoremap           ' . s:AltMapKey('a') . ' :Ag<Space>'
exec 'nnoremap <silent>  ' . s:AltMapKey('d') . ' :call FZFDirectories()<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('b') . ' :Buffers<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('m') . ' :Marks<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('e') . ' :Lines<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('o') . ' :Files %:p:h<CR>'
" exec 'nnoremap <silent> 0' . s:AltMapKey('o') . ' :Files %:p:h<CR>'
exec 'nnoremap <silent> 1' . s:AltMapKey('o') . ' :Files %:p:h/..<CR>'
exec 'nnoremap <silent> 2' . s:AltMapKey('o') . ' :Files %:p:h/../..<CR>'
exec 'nnoremap <silent> 3' . s:AltMapKey('o') . ' :Files %:p:h/../../..<CR>'
exec 'nnoremap <silent> 4' . s:AltMapKey('o') . ' :Files %:p:h/../../../..<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('f') . ' :Files<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('q') . ' :Snippets<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('t') . ' :Filetypes<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('v') . ' :History<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey(';') . ' :History:<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('/') . ' :History/<CR>'

" tmux navigator, window move & split
let g:tmux_navigator_no_mappings = 1
exec 'nnoremap <silent>  ' . s:AltMapKey('h') . ' :TmuxNavigateLeft<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('j') . ' :TmuxNavigateDown<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('k') . ' :TmuxNavigateUp<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('l') . ' :TmuxNavigateRight<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('p') . ' :TmuxNavigatePrevious<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('c') . ' :close<CR>'

exec 'nnoremap <silent>  ' . s:AltMapKey('\') . ' :vsplit<CR>'
exec 'nnoremap <silent>  ' . s:AltMapKey('-') . ' :split<CR>'

" Show unicode names
exec 'nnoremap <silent>  ' . s:AltMapKey('u') . ' :UnicodeName<CR>'

" key pool
exec 'nnoremap           ' . s:AltMapKey('g') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('i') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('n') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('r') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('w') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('x') . ' <NOP>'
exec 'nnoremap           ' . s:AltMapKey('y') . ' <NOP>'

nnoremap <Space>b <NOP>
nnoremap <Space>e <NOP>
nnoremap <Space>i <NOP>
nnoremap <Space>j <NOP>
nnoremap <Space>k <NOP>
nnoremap <Space>l <NOP>
nnoremap <Space>m <NOP>
nnoremap <Space>o <NOP>
nnoremap <Space>s <NOP>
nnoremap <Space>t <NOP>
nnoremap <Space>y <NOP>

" }}

" }}

" Plugin Settings {{

" auto-pairs {{

let g:AutoPairsCompatibleMaps = 1

" }}

" vim-better-whitespace {{

let g:better_whitespace_enabled=1
let g:show_spaces_that_precede_tabs=1
let g:strip_whitespace_on_save=1
let g:strip_whitelines_at_eof=1
let g:strip_whitespace_confirm=0

" }}

" vista.vim {{

function! ToggleVista()
  if exists('*CocHasProvider') && CocHasProvider('documentSymbol')
    let g:vista_default_executive = 'coc'
  else
    let g:vista_default_executive = 'ctags'
  endif
  execute 'Vista!!'
endfunction

nnoremap <silent> <C-T> :call ToggleVista()<CR>

" }}

" rainbow {{

let g:rainbow_active = 1

" }}


" vim-airline {{

let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled = 1

" }}

" vim-cool {{

let g:CoolTotalMatches = 1

" }}

" vim-easy-align {{

vmap ga <PLUG>(EasyAlign)
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
  echo 'GitGutter diff base: ' . g:gitgutter_diff_base
endfunction

nmap <Space>hn <PLUG>(GitGutterNextHunk)
nmap <Space>hp <PLUG>(GitGutterPrevHunk)

nmap <Space>hu <PLUG>(GitGutterUndoHunk)
nmap <Space>hs <PLUG>(GitGutterStageHunk)
nmap <Space>hv <PLUG>(GitGutterPreviewHunk)

nnoremap <silent> \hl :GitGutterLineHighlightsToggle<CR>
nnoremap <silent> \hc :call GitGutterDiffBase()<CR>
nnoremap <silent> \hr :let g:gitgutter_diff_base=''<BAR>call GitGutterDiffBase()<CR>
nnoremap <Space>hb :let g:gitgutter_diff_base=''<LEFT>
for i in range(0, 9)
  exec 'nnoremap <silent> \h' . i . ' :let g:gitgutter_diff_base="HEAD~' . i . '"<BAR>call GitGutterDiffBase()<CR>'
endfor

" text objects
omap ic <PLUG>(GitGutterTextObjectInnerPending)
omap ac <PLUG>(GitGutterTextObjectOuterPending)
vmap ic <PLUG>(GitGutterTextObjectInnerVisual)
vmap ac <PLUG>(GitGutterTextObjectOuterVisual)

" }}

" vim-indent-guides {{

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level = 2
let g:indent_guides_auto_colors = 1

" }}

" vim-peekaboo {{

let g:peekaboo_window = 'vertical leftabove 40new'

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

" vim-gutentags {{

let g:gutentags_file_list_command = 'ag --hidden --ignore .git --ignore .hg --ignore .svn --ignore node_modules -g ""'

" }}

" copilot.vim {{

" let g:copilot_enabled = 1
" inoremap <C-J> <Plug>(copilot-next)
" inoremap <C-K> <Plug>(copilot-previous)
" inoremap <C-Space> <Plug>(copilot-dismiss)

" " Function to toggle Copilot
" function! ToggleCopilot()
"   if copilot#Enabled()
"     Copilot disable
"   else
"     Copilot enable
"   endif
"   Copilot status
" endfunction

" " Map the toggle function to a key, for example, <leader>c
" nnoremap <silent><Space>g :call ToggleCopilot()<CR>

" }}

" coc.nvim {{

nmap <silent><nowait> <Space>cp <Plug>(coc-diagnostic-prev)
nmap <silent><nowait> <Space>cn <Plug>(coc-diagnostic-next)
nnoremap <silent> <Space>cp :call TogglePyrightInlayParameterTypes()<CR>

inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
      \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

function! TogglePyrightInlayParameterTypes()
  let l:config_file = expand('~/.config/nvim/coc-settings.json')
  let l:content = join(readfile(l:config_file), "\n")

  if l:content =~# '"pyright.inlayHints.parameterTypes"\s*:\s*true'
    let l:content = substitute(l:content,
          \ '"pyright.inlayHints.parameterTypes"\s*:\s*true',
          \ '"pyright.inlayHints.parameterTypes": false', '')
    let l:msg = '🧩 parameterTypes inlay hints: OFF'
  else
    let l:content = substitute(l:content,
          \ '"pyright.inlayHints.parameterTypes"\s*:\s*false',
          \ '"pyright.inlayHints.parameterTypes": true', '')
    let l:msg = '🧩 parameterTypes inlay hints: ON'
  endif

  call writefile(split(l:content, "\n"), l:config_file)
  execute ':CocRestart'
  echo l:msg
endfunction

noremap <Space>fm :call CocAction('format')<CR>

" :CocInstall coc-prettier coc-pyright

" }}

" }}

" Plugins & Custom Settings {{

call plug#begin()

let s:custom_vimrc = expand('<sfile>:p:h') . '/' . 'custom/vimrc'
if filereadable(s:custom_vimrc)
  exec 'source ' . s:custom_vimrc
endif

" Insert or delete brackets, parentheses, and quotes in pairs
Plug 'LunarWatcher/auto-pairs'

" argument: jump: '[,' '],'; shift: '<,' '>,'; text-object: 'a,' 'i,'
Plug 'PeterRincker/vim-argumentative'

" git: hunks operation indicator
Plug 'airblade/vim-gitgutter'

" set proper working directory
Plug 'airblade/vim-rooter'

" even better % navigate and highlight matching words
Plug 'andymass/vim-matchup'

" show css color in code
Plug 'ap/vim-css-color'

" pane navigate integration with tmux
Plug 'christoomey/vim-tmux-navigator'

" copilot
" Plug 'github/copilot.vim'

" windsurf
Plug 'Exafunction/windsurf.vim', { 'branch': 'main' }

" fzf integration
Plug 'junegunn/fzf'

" provide utility commands to fzf in a list of certain targets
Plug 'junegunn/fzf.vim'

" ga to align a region of text on a key (<C-X> to use a regex)
Plug 'junegunn/vim-easy-align'

" preview registers for \", @ in normal mode and <C-R> in insert mode
Plug 'junegunn/vim-peekaboo'

" s: motion to match 2 characters
Plug 'justinmk/vim-sneak'

" Viewer & Finder for LSP symbols and tags
Plug 'liuchengxu/vista.vim'

" Decorate brackets, parens and pairs with pairing colors
Plug 'luochen1990/rainbow'

" multiple cursor and multiple modifications
Plug 'mg979/vim-visual-multi'

" Deletes the current buffer smartly
Plug 'mhinz/vim-sayonara'

" highlight trailing blanks and strip whitespace on save
Plug 'ntpeters/vim-better-whitespace'

" visually displaying indent levels
Plug 'preservim/vim-indent-guides'

" disables search highlighting when you are done searching
Plug 'romainl/vim-cool'

" plugin that adds a 'cut' operation separate from 'delete'
Plug 'svermeulen/vim-cutlass'

" maintains a yank history to cycle between when pasting
Plug 'svermeulen/vim-yoink'

" +, - to expand and shrink selection
Plug 'terryma/vim-expand-region'

" deal with multiple variants of a word
Plug 'tpope/vim-abolish'

" gc to comment codes
Plug 'tpope/vim-commentary'

" `.` supports to repeat mapped key sequence
Plug 'tpope/vim-repeat'

" default settings
Plug 'tpope/vim-sensible'

" Auto shiftwidth and expandtab
Plug 'tpope/vim-sleuth'

" use CTRL-A/CTRL-X to increment dates, times, and more
Plug 'tpope/vim-speeddating'

" `s`: manipulate surrounded symbols / texts
Plug 'tpope/vim-surround'

" a bunch of useful [, ] key bindings
Plug 'tpope/vim-unimpaired'

" color scheme
Plug 'sainnhe/gruvbox-material'

" status line with powerline fonts
Plug 'vim-airline/vim-airline',!exists('g:vscode') ? {} : { 'on': [] }

" completions
Plug 'neoclide/coc.nvim', !exists('g:vscode') ? {'branch': 'release'} : { 'on': [] }

" snippets
Plug 'honza/vim-snippets', !exists('g:vscode') ? {} : { 'on': [] }

" ctags
Plug 'ludovicchabant/vim-gutentags', executable('ctags') && !exists('g:vscode') ? {} : { 'on': [] }

" osc52
Plug 'ojroques/nvim-osc52'

call plug#end()

" Color Scheme
if !exists('g:colors_name')
  if has('termguicolors')
    set termguicolors
  endif

  set background=dark

  let g:gruvbox_material_background = 'hard'
  let g:gruvbox_material_better_performance = 1

  if !exists('g:vscode')
    colorscheme gruvbox-material
  endif

  " temporary fix for vim 9.1.1400
  highlight default link luaParenError Error
endif

" }}
