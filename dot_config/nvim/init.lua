vim.env.MYVIMRC = vim.fn.stdpath("config") .. "/init.lua"

require("ravy.options").setup()
require("ravy.commands").setup()
require("ravy.autocmds").setup()
require("ravy.keymaps").setup()

local private = require("ravy.private").load()

if vim.env.RAVY_NVIM_SKIP_PLUGINS ~= "1" then
  require("ravy.plugins").setup(private.plugins)
end

if type(private.after) == "function" then
  local ok, err = pcall(private.after)
  if not ok then
    vim.notify("private nvim after hook failed: " .. tostring(err), vim.log.levels.WARN)
  end
end
