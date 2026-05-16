local M = {}

local function normalize_private_result(result)
  if type(result) ~= "table" then
    return { plugins = {}, after = nil }
  end

  if result.plugins ~= nil or result.after ~= nil then
    return {
      plugins = type(result.plugins) == "table" and result.plugins or {},
      after = result.after,
    }
  end

  return { plugins = result, after = nil }
end

function M.load()
  local private_home = vim.env.RAVY_PRIVATE_HOME
  if private_home == nil or private_home == "" then
    private_home = vim.fn.expand("~/.local/share/ravy-private")
  end

  local private_init = private_home .. "/nvim/init.lua"
  if vim.fn.filereadable(private_init) ~= 1 then
    return { plugins = {}, after = nil }
  end

  local ok, result = pcall(dofile, private_init)
  if not ok then
    vim.notify("private nvim config failed: " .. tostring(result), vim.log.levels.WARN)
    return { plugins = {}, after = nil }
  end

  return normalize_private_result(result)
end

return M
