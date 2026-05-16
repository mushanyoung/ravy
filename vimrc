" Modeline {{
" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker:
" }}

"Plugin cleanup notes:
"- vim-sayonara can be replaced with a native bdelete/bwipe mapping if buffer closing behavior does not need Sayonara's window/tab handling.
"- vim-cool can be removed if manual :nohlsearch or the default <C-L> behavior is enough.
"- vim-better-whitespace can be replaced with a small trailing-whitespace highlight and BufWritePre strip autocmd.
"- vim-airline can be removed for Neovim's default statusline/tabline or a lighter native Lua statusline, but this changes visible UI.
"- coc.nvim can be migrated to Neovim's built-in LSP/completion stack; this is a larger behavior change, not a simple deletion.
"- vim-gitgutter can be replaced with a Neovim-native signs plugin such as gitsigns.nvim.

" Settings {{

" Neovim
set shadafile=~/.config/nvim/main.shada

" General
set directory=~/.config/nvim/swap// swapfile
set backupdir=~/.config/nvim/backup// nobackup writebackup
set undodir=~/.config/nvim/undo// undofile undolevels=1000 undoreload=10000
set wildignore+=*.png,*.jpg,*.gif,*.ico,*.mp3,*.mp4,*.avi,*.mkv,*.o,*.obj,*.pyc,*.swf,*.fla,*.git*,*.hg*,*.svn,log/**,tmp/**,*~,*~orig,*.DS_Store,tags,.tags,.tags_sorted_by_file,node_modules
set fileencodings=ucs-bom,utf-8,default,latin1,utf-16le,big5,gbk,euc-jp,euc-kr,iso8859-1
set formatoptions=nmMcroql
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab smarttab
set copyindent smartindent nocindent
set ignorecase smartcase
set hlsearch incsearch
set modeline modelines=9
set shell=bash
set mouse=a
set iskeyword+=-
set updatetime=100
set notimeout                    " no timeout for key map sequence
set splitright splitbelow        " split window: vertical to the right and horizontal to the below
set synmaxcol=4096               " max columnlength for syntax parsing
set switchbuf=useopen            " when switching to a buffer, jump to a window with it opened
set nostartofline                " does not move the cursor to start of line for some commands
set scrolloff=3 scrolljump=1     " 3 lines away from margins to scroll 1 line
set sidescrolloff=8 sidescroll=2 " 8 columns away from margins to scroll 2 column

" Copy to the terminal clipboard with OSC 52 without querying paste support.
lua << EOF
local osc52 = require('vim.ui.clipboard.osc52')
local cache = {
  ['+'] = { {}, 'v' },
  ['*'] = { {}, 'v' },
}

local function copy(reg)
  local osc52_copy = osc52.copy(reg)
  return function(lines, regtype)
    cache[reg] = { lines, regtype }
    return osc52_copy(lines, regtype)
  end
end

local function paste(reg)
  return function()
    return cache[reg]
  end
end

vim.g.clipboard = {
  name = 'OSC 52 copy-only',
  copy = {
    ['+'] = copy('+'),
    ['*'] = copy('*'),
  },
  paste = {
    ['+'] = paste('+'),
    ['*'] = paste('*'),
  },
}
EOF
set clipboard+=unnamed,unnamedplus

" UI
set number
set nofoldenable foldmethod=indent foldnestmax=3
set list listchars=tab:›\ ,trail:•,extends:>,precedes:<,nbsp:.
set showmatch matchpairs+=<:>
set viewoptions=folds,options,cursor,unix,slash
set title titlestring=✏️\ \ %t:%l%(\ %m%r%h%w%)
set textwidth=120
set winwidth=79 winheight=5 winminheight=5
set linebreak breakindent showbreak=>>
set noshowmode
set lazyredraw
set visualbell
set wildmode=list:longest,full " completions: list matches, then longest common part, then all.
set wrap whichwrap=b,s,h,l,<,>,[,]      " Backspace and cursor keys wrap too
set colorcolumn=+1                      " highlight over width boundary
set virtualedit=onemore                 " cursor beyond last character
set shortmess+=filmnrxoOtTI             " Abbreviation of file messages: try <C-G>

" make cursor a non-blinking vertical bar in insert mode and a non-blinking block elsewhere
let &t_ti.="\e[2 q"
let &t_te.="\e[2 q"
let &t_SI="\e[6 q"
let &t_EI="\e[2 q"

" }}

" Autocmds {{

augroup BufferEdit
  autocmd!

  " restore cursor position when read a buffer
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif

  " set the cursor position to the beginning when editing commit message
  autocmd BufReadPost COMMIT_EDITMSG normal gg0

  " Treat chezmoi KDL templates as KDL.
  autocmd BufReadPost,BufNewFile,BufWinEnter *.kdl.tmpl setlocal filetype=kdl

  " highlight cursorline only in insert mode
  autocmd InsertEnter * set cursorline
  autocmd InsertLeave * set nocursorline
augroup END

" }}

" Functions {{

function! s:zellij_switch_mode(mode) abort
  if empty($ZELLIJ) || empty($ZELLIJ_PANE_ID) || !executable('zellij')
    return
  endif

  silent! call system(['zellij', 'action', 'switch-mode', a:mode])
endfunction

function! s:zellij_start_lock_watch() abort
  if empty($ZELLIJ) || empty($ZELLIJ_PANE_ID) || !executable('zellij-nvim-lock-watch') || !exists('*jobstart')
    return
  endif

  silent! call jobstart(['zellij-nvim-lock-watch'], {'detach': v:true})
endfunction

augroup zellij_lock
  autocmd!
  autocmd VimEnter * call s:zellij_switch_mode('locked')
  autocmd VimEnter * call s:zellij_start_lock_watch()
  autocmd VimLeavePre * call s:zellij_switch_mode('normal')
  if exists('##VimSuspend')
    autocmd VimSuspend * call s:zellij_switch_mode('normal')
  endif
  if exists('##VimResume')
    autocmd VimResume * call s:zellij_switch_mode('locked')
    autocmd VimResume * call s:zellij_start_lock_watch()
  endif
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
nnoremap <silent> <Space><CR> :<C-U>call append(line('.'), repeat([''], v:count1))<CR>
nnoremap <silent> <Space><Space> :<C-U>call append(line('.') - 1, repeat([''], v:count1))<CR>

" FZF
nnoremap <A-a> :Ag<Space>
nnoremap <silent> <A-d> :call FZFDirectories()<CR>
nnoremap <silent> <A-b> :Buffers<CR>
nnoremap <silent> <A-m> :Marks<CR>
nnoremap <silent> <A-e> :Lines<CR>
nnoremap <silent> <A-o> :Files %:p:h<CR>
nnoremap <silent> 1<A-o> :Files %:p:h/..<CR>
nnoremap <silent> 2<A-o> :Files %:p:h/../..<CR>
nnoremap <silent> 3<A-o> :Files %:p:h/../../..<CR>
nnoremap <silent> 4<A-o> :Files %:p:h/../../../..<CR>
nnoremap <silent> <A-f> :Files<CR>
nnoremap <silent> <A-t> :Filetypes<CR>
nnoremap <silent> <A-v> :History<CR>
nnoremap <silent> <A-;> :History:<CR>
nnoremap <silent> <A-/> :History/<CR>

nnoremap <silent> <A-c> :close<CR>

nnoremap <silent> <A-\> :vsplit<CR>
nnoremap <silent> <A--> :split<CR>

" Show unicode names
nnoremap <silent> <A-u> :UnicodeName<CR>

" key pool
nnoremap <A-g> <NOP>
nnoremap <A-i> <NOP>
nnoremap <A-n> <NOP>
nnoremap <A-r> <NOP>
nnoremap <A-w> <NOP>
nnoremap <A-x> <NOP>
nnoremap <A-y> <NOP>

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

let g:gutentags_file_list_command = "rg --files --hidden --glob '!.git' --glob '!.hg' --glob '!.svn' --glob '!node_modules'"

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

inoremap <silent><expr> <TAB> RavyTabComplete()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
      \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

function! RavyTabComplete() abort
  if exists('*luaeval') && luaeval('type(_G.ravy_codeium_has_completion) == "function" and _G.ravy_codeium_has_completion()')
    return luaeval('_G.ravy_codeium_accept()')
  endif

  return coc#pum#visible() ? coc#pum#next(1) :
        \ CheckBackspace() ? "\<Tab>" :
        \ coc#refresh()
endfunction

noremap <Space>fm :call CocAction('format')<CR>

" :CocInstall coc-pyright

" }}

" }}

" Plugins & Custom Settings {{

call plug#begin()

let s:private_home = $RAVY_PRIVATE_HOME
if empty(s:private_home)
  let s:private_home = expand('~/.local/share/ravy-private')
endif

let s:custom_vimrc = s:private_home . '/vimrc'
if filereadable(s:custom_vimrc)
  execute 'source ' . fnameescape(s:custom_vimrc)
endif

" Insert or delete brackets, parentheses, and quotes in pairs
Plug 'LunarWatcher/auto-pairs'

" argument: jump: '[,' '],'; shift: '<,' '>,'; text-object: 'a,' 'i,'
Plug 'PeterRincker/vim-argumentative'

" git: hunks operation indicator
Plug 'airblade/vim-gitgutter'

" set proper working directory
Plug 'airblade/vim-rooter'

" show css color in code
Plug 'ap/vim-css-color'

" copilot
" Plug 'github/copilot.vim'

" windsurf
Plug 'nvim-lua/plenary.nvim'
Plug 'Exafunction/windsurf.nvim'

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

" `.` supports to repeat mapped key sequence
Plug 'tpope/vim-repeat'

" Auto shiftwidth and expandtab
Plug 'tpope/vim-sleuth'

" use CTRL-A/CTRL-X to increment dates, times, and more
Plug 'tpope/vim-speeddating'

" `s`: manipulate surrounded symbols / texts
Plug 'tpope/vim-surround'

" color scheme
Plug 'sainnhe/gruvbox-material'

" status line with powerline fonts
Plug 'vim-airline/vim-airline',!exists('g:vscode') ? {} : { 'on': [] }

" completions
Plug 'neoclide/coc.nvim', !exists('g:vscode') ? {'branch': 'release'} : { 'on': [] }

" ctags
Plug 'ludovicchabant/vim-gutentags', executable('ctags') && !exists('g:vscode') ? {} : { 'on': [] }

call plug#end()

" windsurf.nvim {{
if !exists('g:vscode')
lua << EOF
local ok, codeium = pcall(require, "codeium")
if ok then
  local setup_ok, setup_err = pcall(codeium.setup, {
    enable_cmp_source = false,
    virtual_text = {
      enabled = true,
      key_bindings = {
        accept = false,
      },
    },
  })

  if not setup_ok then
    vim.notify("windsurf.nvim setup failed: " .. tostring(setup_err), vim.log.levels.WARN)
  end
end

function _G.ravy_codeium_has_completion()
  local vt_ok, vt = pcall(require, "codeium.virtual_text")
  return vt_ok and vt.get_current_completion_item() ~= nil
end

function _G.ravy_codeium_accept()
  local vt_ok, vt = pcall(require, "codeium.virtual_text")
  if vt_ok then
    return vim.api.nvim_replace_termcodes(vt.accept(), true, true, true)
  end
  return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
end
EOF
endif

" }}

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
