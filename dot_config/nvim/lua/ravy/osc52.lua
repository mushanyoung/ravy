local M = {}

function M.setup()
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
    return
  end

  local cache = {
    ["+"] = { {}, "v" },
    ["*"] = { {}, "v" },
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
    name = "OSC 52 copy-only",
    copy = {
      ["+"] = copy("+"),
      ["*"] = copy("*"),
    },
    paste = {
      ["+"] = paste("+"),
      ["*"] = paste("*"),
    },
  }

  vim.opt.clipboard:append({ "unnamed", "unnamedplus" })
end

return M
