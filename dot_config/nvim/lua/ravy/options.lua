local M = {}

local function mkdir(path)
  vim.fn.mkdir(path, "p")
end

function M.setup()
  local config = vim.fn.stdpath("config")

  mkdir(config .. "/swap")
  mkdir(config .. "/backup")
  mkdir(config .. "/undo")

  vim.opt.shadafile = config .. "/main.shada"

  vim.opt.directory = config .. "/swap//"
  vim.opt.swapfile = true
  vim.opt.backupdir = config .. "/backup//"
  vim.opt.backup = false
  vim.opt.writebackup = true
  vim.opt.undodir = config .. "/undo//"
  vim.opt.undofile = true
  vim.opt.undolevels = 1000
  vim.opt.undoreload = 10000

  vim.opt.wildignore:append({
    "*.png",
    "*.jpg",
    "*.gif",
    "*.ico",
    "*.mp3",
    "*.mp4",
    "*.avi",
    "*.mkv",
    "*.o",
    "*.obj",
    "*.pyc",
    "*.swf",
    "*.fla",
    "*.git*",
    "*.hg*",
    "*.svn",
    "log/**",
    "tmp/**",
    "*~",
    "*~orig",
    "*.DS_Store",
    "tags",
    ".tags",
    ".tags_sorted_by_file",
    "node_modules",
  })

  vim.opt.fileencodings = {
    "ucs-bom",
    "utf-8",
    "default",
    "latin1",
    "utf-16le",
    "big5",
    "gbk",
    "euc-jp",
    "euc-kr",
    "iso8859-1",
  }
  vim.opt.formatoptions = "nmMcroql"
  vim.opt.sessionoptions = { "blank", "buffers", "curdir", "folds", "tabpages", "winsize" }
  vim.opt.tabstop = 2
  vim.opt.softtabstop = 2
  vim.opt.shiftwidth = 2
  vim.opt.expandtab = true
  vim.opt.smarttab = true
  vim.opt.copyindent = true
  vim.opt.smartindent = true
  vim.opt.cindent = false
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.hlsearch = true
  vim.opt.incsearch = true
  vim.opt.modeline = true
  vim.opt.modelines = 9
  vim.opt.shell = "bash"
  vim.opt.mouse = "a"
  vim.opt.iskeyword:append("-")
  vim.opt.updatetime = 100
  vim.opt.timeout = false
  vim.opt.splitright = true
  vim.opt.splitbelow = true
  vim.opt.synmaxcol = 4096
  vim.opt.switchbuf = "useopen"
  vim.opt.startofline = false
  vim.opt.scrolloff = 3
  vim.opt.scrolljump = 1
  vim.opt.sidescrolloff = 8
  vim.opt.sidescroll = 2

  vim.opt.number = true
  vim.opt.foldenable = false
  vim.opt.foldmethod = "indent"
  vim.opt.foldnestmax = 3
  vim.opt.list = true
  vim.opt.listchars = { tab = "> ", trail = "-", extends = ">", precedes = "<", nbsp = "." }
  vim.opt.showmatch = true
  vim.opt.matchpairs:append("<:>")
  vim.opt.viewoptions = { "folds", "options", "cursor", "unix", "slash" }
  vim.opt.title = true
  vim.opt.titlestring = "nvim %t:%l%(%m%r%h%w%)"
  vim.opt.textwidth = 120
  vim.opt.winwidth = 79
  vim.opt.winheight = 5
  vim.opt.winminheight = 5
  vim.opt.linebreak = true
  vim.opt.breakindent = true
  vim.opt.showbreak = ">>"
  vim.opt.showmode = false
  vim.opt.lazyredraw = true
  vim.opt.visualbell = true
  vim.opt.wildmode = { "list:longest", "full" }
  vim.opt.wrap = true
  vim.opt.whichwrap = "b,s,h,l,<,>,[,]"
  vim.opt.colorcolumn = "+1"
  vim.opt.virtualedit = "onemore"
  vim.opt.shortmess:append("filmnrxoOtTI")
  vim.opt.guicursor = {
    "n-v-c-sm:block-blinkwait0-blinkon0-blinkoff0",
    "i-ci-ve:ver25-blinkwait0-blinkon0-blinkoff0",
    "r-cr-o:hor20-blinkwait0-blinkon0-blinkoff0",
  }

  vim.opt.termguicolors = true
  vim.opt.background = "dark"

  require("ravy.osc52").setup()
end

return M
