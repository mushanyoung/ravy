local M = {}

local function builtin_call(name, opts)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("telescope.nvim is not available", vim.log.levels.WARN)
    return
  end

  builtin[name](opts or {})
end

local function buffer_dir()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    return vim.fn.getcwd()
  end
  return dir
end

local function climb(path, levels)
  local result = path
  for _ = 1, levels do
    local parent = vim.fs.dirname(result)
    if parent == nil or parent == result then
      break
    end
    result = parent
  end
  return result
end

function M.live_grep()
  builtin_call("live_grep")
end

function M.directories()
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_actions, actions = pcall(require, "telescope.actions")
  local ok_state, action_state = pcall(require, "telescope.actions.state")
  local ok_config, config = pcall(require, "telescope.config")
  local ok_previewers, previewers = pcall(require, "telescope.previewers")

  if not (ok_pickers and ok_finders and ok_actions and ok_state and ok_config) then
    vim.notify("telescope.nvim is not available", vim.log.levels.WARN)
    return
  end

  local results = vim.fn.systemlist({
    "bash",
    "-lc",
    [[(echo ./..; find . -type d -not -path "*/\.*" | sed 1d) | cut -b3-]],
  })

  local previewer = nil
  if ok_previewers and vim.fn.executable("eza") == 1 then
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry)
        return { "eza", "--tree", "--color=always", entry.value }
      end,
    })
  end

  pickers
    .new({}, {
      prompt_title = "Dir",
      finder = finders.new_table({ results = results }),
      sorter = config.values.generic_sorter({}),
      previewer = previewer,
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection == nil then
            return
          end
          vim.cmd.cd(vim.fn.fnameescape(selection.value))
          print(vim.fn.getcwd())
        end)
        return true
      end,
    })
    :find()
end

function M.buffers()
  builtin_call("buffers")
end

function M.marks()
  builtin_call("marks")
end

function M.lines()
  builtin_call("current_buffer_fuzzy_find")
end

function M.files_near_buffer(levels)
  builtin_call("find_files", { cwd = climb(buffer_dir(), levels or 0), hidden = true })
end

function M.files()
  builtin_call("find_files", { hidden = true })
end

function M.filetypes()
  builtin_call("filetypes")
end

function M.oldfiles()
  builtin_call("oldfiles")
end

function M.command_history()
  builtin_call("command_history")
end

function M.search_history()
  builtin_call("search_history")
end

function M.setup()
  local telescope = require("telescope")
  local actions = require("telescope.actions")

  telescope.setup({
    defaults = {
      mappings = {
        i = {
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
      },
    },
    pickers = {
      find_files = {
        hidden = true,
      },
    },
  })

  pcall(telescope.load_extension, "fzf")
end

return M
