local M = {}

function M.has_completion()
  local ok, virtual_text = pcall(require, "codeium.virtual_text")
  return ok and virtual_text.get_current_completion_item() ~= nil
end

function M.accept()
  local ok, virtual_text = pcall(require, "codeium.virtual_text")
  if ok then
    return vim.api.nvim_replace_termcodes(virtual_text.accept(), true, true, true)
  end
  return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
end

function M.setup()
  local ok, codeium = pcall(require, "codeium")
  if not ok then
    return
  end

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

  _G.ravy_codeium_has_completion = M.has_completion
  _G.ravy_codeium_accept = M.accept
end

return M
