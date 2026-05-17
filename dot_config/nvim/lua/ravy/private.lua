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
  local ravy_home = vim.env.RAVY_HOME
  if ravy_home == nil or ravy_home == "" then
    ravy_home = vim.fn.expand("~/.local/share/chezmoi")
  end

  local default_private_home = ravy_home .. "/custom"
  local private_home = vim.env.RAVY_PRIVATE_HOME
  if private_home == nil or private_home == "" then
    private_home = default_private_home
  end

  local private_init = private_home .. "/nvim/init.lua"
  if vim.fn.filereadable(private_init) ~= 1 then
    for _, fallback_home in ipairs({
      default_private_home,
      vim.fn.expand("~/.local/share/ravy-private"),
      vim.fn.expand("~/.ravy-private"),
    }) do
      local fallback_init = fallback_home .. "/nvim/init.lua"
      if fallback_home ~= private_home and vim.fn.filereadable(fallback_init) == 1 then
        private_init = fallback_init
        break
      end
    end
  end

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
