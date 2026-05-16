local M = {}

local function check_backspace()
  local col = vim.fn.col(".") - 1
  return col == 0 or vim.fn.getline("."):sub(col, col):match("%s") ~= nil
end

function M.tab_complete()
  local codeium = require("ravy.codeium")
  if codeium.has_completion() then
    return codeium.accept()
  end

  if vim.fn["coc#pum#visible"]() == 1 then
    return vim.fn["coc#pum#next"](1)
  end

  if check_backspace() then
    return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
  end

  return vim.fn["coc#refresh"]()
end

function M.shift_tab()
  if vim.fn["coc#pum#visible"]() == 1 then
    return vim.fn["coc#pum#prev"](1)
  end
  return vim.api.nvim_replace_termcodes("<C-h>", true, true, true)
end

function M.confirm_or_enter()
  if vim.fn["coc#pum#visible"]() == 1 then
    return vim.fn["coc#pum#confirm"]()
  end
  return vim.api.nvim_replace_termcodes("<C-g>u<CR><C-r>=coc#on_enter()<CR>", true, false, true)
end

function M.setup()
  local map = vim.keymap.set

  map("n", "<Space>cp", "<Plug>(coc-diagnostic-prev)", { silent = true, nowait = true, remap = true })
  map("n", "<Space>cn", "<Plug>(coc-diagnostic-next)", { silent = true, nowait = true, remap = true })
  map("i", "<Tab>", M.tab_complete, { silent = true, expr = true })
  map("i", "<S-Tab>", M.shift_tab, { expr = true })
  map("i", "<CR>", M.confirm_or_enter, { silent = true, expr = true })
  map("n", "<Space>fm", function()
    vim.fn.CocAction("format")
  end)
end

return M
