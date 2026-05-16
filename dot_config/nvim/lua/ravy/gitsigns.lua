local M = {}

local function set_base(base)
  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok then
    return
  end

  vim.g.ravy_gitsigns_diff_base = base or ""
  gitsigns.change_base(base ~= "" and base or nil, true)
  print("Gitsigns diff base: " .. (base ~= "" and base or "index"))
end

local function prompt_base()
  vim.ui.input({ prompt = "Gitsigns diff base: ", default = vim.g.ravy_gitsigns_diff_base or "" }, function(base)
    if base ~= nil then
      set_base(base)
    end
  end)
end

function M.setup()
  require("gitsigns").setup({
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")
      local opts = { buffer = bufnr, silent = true }

      vim.keymap.set("n", "<Space>hn", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gitsigns.nav_hunk("next")
        end
      end, opts)

      vim.keymap.set("n", "<Space>hp", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gitsigns.nav_hunk("prev")
        end
      end, opts)

      vim.keymap.set("n", "<Space>hu", gitsigns.reset_hunk, opts)
      vim.keymap.set("n", "<Space>hs", gitsigns.stage_hunk, opts)
      vim.keymap.set("n", "<Space>hv", gitsigns.preview_hunk, opts)
      vim.keymap.set("n", "\\hl", gitsigns.toggle_linehl, opts)
      vim.keymap.set("n", "\\hc", function()
        set_base(vim.g.ravy_gitsigns_diff_base or "")
      end, opts)
      vim.keymap.set("n", "\\hr", function()
        set_base("")
      end, opts)
      vim.keymap.set("n", "<Space>hb", prompt_base, opts)

      for i = 0, 9 do
        vim.keymap.set("n", "\\h" .. i, function()
          set_base("HEAD~" .. i)
        end, opts)
      end

      vim.keymap.set({ "o", "x" }, "ic", ":<C-U>Gitsigns select_hunk<CR>", opts)
      vim.keymap.set({ "o", "x" }, "ac", ":<C-U>Gitsigns select_hunk<CR>", opts)
    end,
  })
end

return M
