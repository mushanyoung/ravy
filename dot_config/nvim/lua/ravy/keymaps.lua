local M = {}

local function map(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { silent = false }, opts or {}))
end

local function cmd(command)
  return "<Cmd>" .. command .. "<CR>"
end

local function append_empty_lines(after)
  local count = vim.v.count1
  local lines = {}
  for _ = 1, count do
    table.insert(lines, "")
  end

  local line = vim.fn.line(".")
  local index = after and line or line - 1
  vim.api.nvim_buf_set_lines(0, index, index, false, lines)
end

local function toggle_quickfix()
  local qf = vim.fn.getqflist({ winid = 0 })
  if qf.winid ~= 0 then
    vim.cmd.cclose()
  else
    vim.cmd.copen()
  end
end

local function toggle_foldenable()
  vim.wo.foldenable = not vim.wo.foldenable
  print(vim.wo.foldenable and "Fold enabled." or "Fold disabled.")
end

local function toggle_scrolloff()
  vim.opt.scrolloff = 999 - vim.o.scrolloff
  print(vim.o.scrolloff < 20 and "Auto zz disabled." or "Auto zz enabled.")
end

local function show_maps()
  local output = vim.api.nvim_exec2("silent map\nsilent map!", { output = true }).output
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, "\n", { plain = true }))
end

local function split_cfile()
  local file = vim.fn.expand("<cfile>")
  if file == "" then
    return
  end
  vim.cmd.vsplit(vim.fn.fnameescape(file))
end

local function setup_cutlass_maps()
  local mappings = {
    { { "n", "x" }, "c", '"_c' },
    { "n", "cc", '"_S' },
    { { "n", "x" }, "C", '"_C' },
    { { "n", "x" }, "s", '"_s' },
    { { "n", "x" }, "S", '"_S' },
    { { "n", "x" }, "d", '"_d' },
    { "n", "dd", '"_dd' },
    { { "n", "x" }, "D", '"_D' },
    { { "n", "x" }, "x", '"_x' },
    { { "n", "x" }, "X", '"_X' },
  }

  for _, mapping in ipairs(mappings) do
    map(mapping[1], mapping[2], mapping[3], { silent = true })
  end
end

function M.setup()
  vim.g.mapleader = ">"

  setup_cutlass_maps()

  map("i", "jj", "<Esc>")
  map("n", "<C-E>", "3<C-E>")
  map("n", "<C-Y>", "3<C-Y>")
  map("n", "H", "^")
  map("n", "L", "$")
  map("n", "m", "d")
  map("x", "m", "d")
  map("n", "mm", "dd")
  map("n", "M", "D")
  map("x", "p", '"_dP')
  map("n", "Y", "y$")
  map("x", "<Space>/", ":s/")
  map("n", "<Space>/", ":%s/")
  map("n", "<Space>a", "ggVG")
  map("n", "<Space>w", cmd("write"))

  map("i", "<C-J>", "<C-N>")
  map("i", "<C-K>", "<C-P>")
  map("i", "<C-C>", "<C-[>")
  map("c", "%%", function()
    return vim.fn.getcmdtype() == ":" and vim.fn.expand("%:h") .. "/" or "%%"
  end, { expr = true })
  map("c", "w!!", "w !sudo tee % >/dev/null")
  map("c", "<C-P>", "<Up>")
  map("c", "<C-N>", "<Down>")
  map("c", "<Up>", "<C-P>")
  map("c", "<Down>", "<C-N>")
  map("i", "<C-A>", "<C-O>^")
  map("c", "<C-A>", "<Home>")
  map("i", "<C-E>", function()
    if vim.fn.col(".") > #vim.fn.getline(".") or vim.fn.pumvisible() == 1 then
      return "<C-E>"
    end
    return "<End>"
  end, { expr = true })

  map("n", "gb", cmd("bprevious"))
  map("n", "gB", cmd("bnext"))
  map("n", "gw", split_cfile)
  map("n", "gV", "`[v`]")
  map({ "n", "x" }, "/", "/\\v")
  map("n", "<Space>x", cmd("RavyBdelete"))
  map("n", "<Space>de", function()
    vim.cmd.bdelete({ bang = true })
    vim.cmd.diffoff()
  end, { silent = true })
  map("n", "<Space>dl", function()
    vim.cmd("diffget 1 | diffupdate")
  end, { silent = true })
  map("n", "<Space>db", function()
    vim.cmd("diffget 2 | diffupdate")
  end, { silent = true })
  map("n", "<Space>dr", function()
    vim.cmd("diffget 3 | diffupdate")
  end, { silent = true })
  map("n", "<Space>ff", function()
    print(vim.fn.getcwd() .. " > " .. vim.fn.expand("%"))
  end)
  map("n", "<Space>f.", function()
    vim.cmd.lcd("..")
    print(vim.fn.getcwd())
  end)
  map("n", "<Space>fh", function()
    vim.cmd.lcd(vim.fn.fnameescape(vim.fn.expand("%:p:h")))
    print(vim.fn.getcwd())
  end)
  map("n", "<Space>fe", ":lcd ")
  map("n", "<Space>n", cmd("enew"))
  map("n", "<Space>q", toggle_quickfix, { silent = true })
  map("n", "<Space>u", toggle_foldenable, { silent = true })
  map("n", "<Space>ve", cmd("edit $MYVIMRC"))
  map("n", "<Space>vs", cmd("RavyReload"))
  map("n", "<Space>vm", show_maps)
  map("n", "<Space>vu", cmd("Lazy sync"))
  map("n", "<Space>vc", cmd("Lazy clean"))
  map("n", "<Space>r", ':!"%:p"<CR>')
  map("n", "<Space>z", toggle_scrolloff, { silent = true })
  map("n", "<Tab>", "v>")
  map("n", "<S-Tab>", "v<")
  map("x", "<Tab>", ">gv")
  map("x", "<S-Tab>", "<gv")
  map("n", "<Space><CR>", function()
    append_empty_lines(true)
  end, { silent = true })
  map("n", "<Space><Space>", function()
    append_empty_lines(false)
  end, { silent = true })

  local telescope = require("ravy.telescope")
  map("n", "<A-a>", telescope.live_grep)
  map("n", "<A-d>", telescope.directories, { silent = true })
  map("n", "<A-b>", telescope.buffers, { silent = true })
  map("n", "<A-m>", telescope.marks, { silent = true })
  map("n", "<A-e>", telescope.lines, { silent = true })
  map("n", "<A-o>", function()
    telescope.files_near_buffer(0)
  end, { silent = true })
  map("n", "1<A-o>", function()
    telescope.files_near_buffer(1)
  end, { silent = true })
  map("n", "2<A-o>", function()
    telescope.files_near_buffer(2)
  end, { silent = true })
  map("n", "3<A-o>", function()
    telescope.files_near_buffer(3)
  end, { silent = true })
  map("n", "4<A-o>", function()
    telescope.files_near_buffer(4)
  end, { silent = true })
  map("n", "<A-f>", telescope.files, { silent = true })
  map("n", "<A-t>", telescope.filetypes, { silent = true })
  map("n", "<A-v>", telescope.oldfiles, { silent = true })
  map("n", "<A-;>", telescope.command_history, { silent = true })
  map("n", "<A-/>", telescope.search_history, { silent = true })
  map("n", "<A-c>", cmd("close"), { silent = true })
  map("n", "<A-\\>", cmd("vsplit"), { silent = true })
  map("n", "<A-->", cmd("split"), { silent = true })
  map("n", "<A-u>", cmd("UnicodeName"), { silent = true })

  for _, lhs in ipairs({ "<A-g>", "<A-i>", "<A-n>", "<A-r>", "<A-w>", "<A-x>", "<A-y>" }) do
    map("n", lhs, "<Nop>")
  end
  for _, lhs in ipairs({
    "<Space>b",
    "<Space>e",
    "<Space>i",
    "<Space>j",
    "<Space>k",
    "<Space>l",
    "<Space>m",
    "<Space>o",
    "<Space>s",
    "<Space>t",
    "<Space>y",
  }) do
    map("n", lhs, "<Nop>")
  end
end

return M
