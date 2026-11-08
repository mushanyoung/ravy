local M = {}

local function bootstrap_lazy()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if vim.uv.fs_stat(lazypath) == nil then
    local output = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    })
    if vim.v.shell_error ~= 0 then
      error("failed to bootstrap lazy.nvim:\n" .. output)
    end
  end
  vim.opt.rtp:prepend(lazypath)
end

local function plugin_specs()
  vim.g.gruvbox_material_background = "hard"
  vim.g.gruvbox_material_better_performance = 1
  vim.g.gutentags_file_list_command =
    "rg --files --hidden --glob '!.git' --glob '!.hg' --glob '!.svn' --glob '!node_modules'"

  return {
    {
      "sainnhe/gruvbox-material",
      lazy = false,
      priority = 1000,
      config = function()
        if vim.g.colors_name == nil then
          vim.cmd.colorscheme("gruvbox-material")
        end
        vim.cmd("highlight default link luaParenError Error")
      end,
    },
    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        {
          "nvim-telescope/telescope-fzf-native.nvim",
          build = "make",
          cond = function()
            return vim.fn.executable("make") == 1
          end,
        },
      },
      config = function()
        require("ravy.telescope").setup()
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      dependencies = { "neovim-treesitter/treesitter-parser-registry" },
      build = ":TSUpdate",
      lazy = false,
      config = function()
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("RavyTreesitter", { clear = true }),
          callback = function()
            local ok = pcall(vim.treesitter.start)
            if ok then
              pcall(function()
                vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
              end)
            end
          end,
        })
      end,
    },
    {
      "lewis6991/gitsigns.nvim",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("ravy.gitsigns").setup()
      end,
    },
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      event = "VeryLazy",
      config = function()
        require("lualine").setup({
          options = {
            theme = "gruvbox-material",
            component_separators = "",
            section_separators = "",
          },
          extensions = { "quickfix" },
        })
      end,
    },
    {
      "windwp/nvim-autopairs",
      event = "InsertEnter",
      config = function()
        require("nvim-autopairs").setup({ map_cr = false })
      end,
    },
    {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      event = { "BufReadPost", "BufNewFile" },
      opts = {
        indent = { char = "|" },
        scope = { enabled = true },
      },
    },
    {
      "HiPhish/rainbow-delimiters.nvim",
      event = { "BufReadPost", "BufNewFile" },
    },
    {
      "kylechui/nvim-surround",
      event = "VeryLazy",
      config = function()
        require("nvim-surround").setup()
      end,
    },
    {
      url = "https://codeberg.org/andyg/leap.nvim",
      name = "leap.nvim",
      event = "VeryLazy",
      config = function()
        vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)", { desc = "Leap forward" })
        vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)", { desc = "Leap backward" })
        vim.keymap.set("n", "gs", "<Plug>(leap-from-window)", { desc = "Leap from window" })
      end,
    },
    {
      "echasnovski/mini.align",
      version = false,
      event = "VeryLazy",
      config = function()
        require("mini.align").setup()
      end,
    },
    {
      "stevearc/aerial.nvim",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("aerial").setup({
          backends = { "lsp", "treesitter", "markdown", "man" },
          layout = {
            default_direction = "prefer_right",
          },
        })
        vim.keymap.set("n", "<C-T>", function()
          require("aerial").toggle({ focus = false })
        end, { silent = true })
      end,
    },
    {
      "NMAC427/guess-indent.nvim",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("guess-indent").setup()
      end,
    },
    {
      "monaqa/dial.nvim",
      event = "VeryLazy",
      config = function()
        local augend = require("dial.augend")
        require("dial.config").augends:register_group({
          default = {
            augend.integer.alias.decimal,
            augend.integer.alias.hex,
            augend.date.alias["%Y/%m/%d"],
            augend.date.alias["%Y-%m-%d"],
            augend.constant.alias.bool,
          },
        })

        vim.keymap.set("n", "<C-A>", require("dial.map").inc_normal(), { noremap = true })
        vim.keymap.set("n", "<C-X>", require("dial.map").dec_normal(), { noremap = true })
        vim.keymap.set("x", "<C-A>", require("dial.map").inc_visual(), { noremap = true })
        vim.keymap.set("x", "<C-X>", require("dial.map").dec_visual(), { noremap = true })
        vim.keymap.set("x", "g<C-A>", require("dial.map").inc_gvisual(), { noremap = true })
        vim.keymap.set("x", "g<C-X>", require("dial.map").dec_gvisual(), { noremap = true })
      end,
    },
    {
      "gbprod/yanky.nvim",
      event = "VeryLazy",
      config = function()
        require("yanky").setup({
          ring = {
            history_length = 100,
            storage = "shada",
          },
          system_clipboard = {
            sync_with_ring = false,
          },
        })

        vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { remap = true })
        vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { remap = true })
        vim.keymap.set("n", "<C-J>", "<Plug>(YankyCycleBackward)", { remap = true })
        vim.keymap.set("n", "<C-K>", "<Plug>(YankyCycleForward)", { remap = true })
      end,
    },
    {
      "NvChad/nvim-colorizer.lua",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("colorizer").setup()
      end,
    },
    {
      "Exafunction/windsurf.nvim",
      event = "InsertEnter",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("ravy.codeium").setup()
      end,
    },
    {
      "neoclide/coc.nvim",
      branch = "release",
      lazy = false,
      config = function()
        require("ravy.coc").setup()
      end,
    },
    { "PeterRincker/vim-argumentative", event = "VeryLazy" },
    { "mg979/vim-visual-multi", event = "VeryLazy" },
    { "terryma/vim-expand-region", event = "VeryLazy" },
    { "tpope/vim-abolish", event = "VeryLazy" },
    { "tpope/vim-repeat", event = "VeryLazy" },
    {
      "ludovicchabant/vim-gutentags",
      cond = function()
        return vim.fn.executable("ctags") == 1
      end,
      event = { "BufReadPost", "BufNewFile" },
    },
  }
end

function M.setup(private_specs)
  bootstrap_lazy()

  local specs = plugin_specs()
  if type(private_specs) == "table" then
    vim.list_extend(specs, private_specs)
  end

  require("lazy").setup(specs, {
    install = {
      missing = true,
      colorscheme = { "gruvbox-material" },
    },
    change_detection = {
      notify = false,
    },
    checker = {
      enabled = false,
    },
    performance = {
      rtp = {
        disabled_plugins = {
          "gzip",
          "matchit",
          "matchparen",
          "netrwPlugin",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
    },
  })
end

return M
