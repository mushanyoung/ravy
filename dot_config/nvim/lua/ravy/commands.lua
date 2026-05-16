local M = {}

local function close_buffer(force)
  local current = vim.api.nvim_get_current_buf()
  local listed = vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())

  if #listed <= 1 then
    vim.cmd.enew()
  else
    vim.cmd.bprevious()
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, current, { force = force })
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
end

local function unicode_name()
  local line = vim.api.nvim_get_current_line()
  local char_index = math.max(vim.fn.charcol(".") - 1, 0)
  local char = vim.fn.strcharpart(line, char_index, 1)

  if char == "" then
    return
  end

  if vim.fn.executable("python3") == 1 then
    local output = vim.fn.system({
      "python3",
      "-c",
      "import sys, unicodedata as u; ch=sys.argv[1]; print('U+%04X %s' % (ord(ch), u.name(ch, '<unknown>')))",
      char,
    })
    vim.notify(vim.trim(output))
    return
  end

  vim.notify(string.format("U+%04X", vim.fn.char2nr(char)))
end

local function extract_matches(args)
  local pattern = args.args
  local matches = {}

  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    local start = 0
    while true do
      local match = vim.fn.matchstrpos(line, pattern, start)
      if match[2] == -1 then
        break
      end

      table.insert(matches, match[1])
      if match[3] <= start then
        start = start + 1
      else
        start = match[3]
      end
    end
  end

  vim.cmd.new()
  if #matches > 0 then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, matches)
  end
end

local function reload_config()
  for name in pairs(package.loaded) do
    if name == "ravy" or name:match("^ravy%.") then
      package.loaded[name] = nil
    end
  end

  dofile(vim.env.MYVIMRC)
end

function M.setup()
  vim.api.nvim_create_user_command("ExtractMatches", extract_matches, { nargs = 1 })
  vim.api.nvim_create_user_command("UnicodeName", unicode_name, {})
  vim.api.nvim_create_user_command("RavyBdelete", function()
    close_buffer(false)
  end, {})
  vim.api.nvim_create_user_command("RavyBdeleteBang", function()
    close_buffer(true)
  end, {})
  vim.api.nvim_create_user_command("RavyReload", reload_config, {})
end

M.close_buffer = close_buffer

return M
