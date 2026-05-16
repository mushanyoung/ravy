local M = {}

local function zellij_switch_mode(mode)
  if vim.env.ZELLIJ == nil or vim.env.ZELLIJ == "" then
    return
  end
  if vim.env.ZELLIJ_PANE_ID == nil or vim.env.ZELLIJ_PANE_ID == "" then
    return
  end
  if vim.fn.executable("zellij") ~= 1 then
    return
  end

  vim.fn.jobstart({ "zellij", "action", "switch-mode", mode }, { detach = true })
end

local function zellij_start_lock_watch()
  if vim.env.ZELLIJ == nil or vim.env.ZELLIJ == "" then
    return
  end
  if vim.env.ZELLIJ_PANE_ID == nil or vim.env.ZELLIJ_PANE_ID == "" then
    return
  end
  if vim.fn.executable("zellij-nvim-lock-watch") ~= 1 then
    return
  end

  vim.fn.jobstart({ "zellij-nvim-lock-watch" }, { detach = true })
end

local function strip_whitespace()
  if vim.bo.buftype ~= "" or not vim.bo.modifiable or vim.bo.readonly or vim.bo.binary then
    return
  end

  local view = vim.fn.winsaveview()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local changed = false

  for i, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    if stripped ~= line then
      lines[i] = stripped
      changed = true
    end
  end

  while #lines > 1 and lines[#lines] == "" do
    table.remove(lines)
    changed = true
  end

  if changed then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.fn.winrestview(view)
  end
end

local function show_whitespace()
  if vim.bo.buftype ~= "" then
    return
  end

  if vim.w.ravy_whitespace_match_id ~= nil then
    pcall(vim.fn.matchdelete, vim.w.ravy_whitespace_match_id)
  end

  vim.w.ravy_whitespace_match_id = vim.fn.matchadd("ExtraWhitespace", [[\s\+$]])
end

local function hide_whitespace()
  if vim.w.ravy_whitespace_match_id ~= nil then
    pcall(vim.fn.matchdelete, vim.w.ravy_whitespace_match_id)
    vim.w.ravy_whitespace_match_id = nil
  end
end

local root_markers = {
  ".git",
  ".hg",
  ".svn",
  "biome.json",
  "Cargo.toml",
  "deno.json",
  "go.mod",
  "Makefile",
  "package.json",
  "pyproject.toml",
}

local function find_root(path)
  if path == "" then
    return nil
  end

  local stat = vim.uv.fs_stat(path)
  if stat == nil then
    return nil
  end

  local dir = stat.type == "directory" and path or vim.fs.dirname(path)
  local found = vim.fs.find(root_markers, { path = dir, upward = true })
  if found[1] == nil then
    return nil
  end

  return vim.fs.dirname(found[1])
end

local function root_current_buffer()
  if vim.bo.buftype ~= "" then
    return
  end

  local root = find_root(vim.api.nvim_buf_get_name(0))
  if root == nil or root == "" then
    return
  end

  if vim.fn.getcwd(0) ~= root then
    vim.cmd.lcd(vim.fn.fnameescape(root))
  end
end

function M.setup()
  vim.api.nvim_set_hl(0, "ExtraWhitespace", { link = "Error" })

  local buffer_edit = vim.api.nvim_create_augroup("BufferEdit", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = buffer_edit,
    callback = function()
      local mark = vim.api.nvim_buf_get_mark(0, '"')
      local line_count = vim.api.nvim_buf_line_count(0)
      if mark[1] >= 1 and mark[1] <= line_count then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = buffer_edit,
    pattern = "COMMIT_EDITMSG",
    command = "normal! gg0",
  })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWinEnter" }, {
    group = buffer_edit,
    pattern = "*.kdl.tmpl",
    callback = function()
      vim.bo.filetype = "kdl"
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = buffer_edit,
    callback = function()
      vim.wo.cursorline = true
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = buffer_edit,
    callback = function()
      vim.wo.cursorline = false
    end,
  })

  local whitespace = vim.api.nvim_create_augroup("RavyWhitespace", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "InsertLeave" }, {
    group = whitespace,
    callback = show_whitespace,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = whitespace,
    callback = hide_whitespace,
  })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = whitespace,
    callback = strip_whitespace,
  })

  local rooter = vim.api.nvim_create_augroup("RavyRooter", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = rooter,
    callback = root_current_buffer,
  })

  local zellij = vim.api.nvim_create_augroup("zellij_lock", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = zellij,
    callback = function()
      zellij_switch_mode("locked")
      zellij_start_lock_watch()
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = zellij,
    callback = function()
      zellij_switch_mode("normal")
    end,
  })
  vim.api.nvim_create_autocmd("VimSuspend", {
    group = zellij,
    callback = function()
      zellij_switch_mode("normal")
    end,
  })
  vim.api.nvim_create_autocmd("VimResume", {
    group = zellij,
    callback = function()
      zellij_switch_mode("locked")
      zellij_start_lock_watch()
    end,
  })
end

return M
