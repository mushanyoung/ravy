local root = assert(vim.env.RAVY_NVIM_TEST_ROOT)
local function eq(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. ": " .. vim.inspect(actual))
end

local function edit(name, lines)
  vim.cmd("enew!")
  vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. name))
  if lines then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
end

local function save()
  vim.cmd("silent write")
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

edit("breaks.md", { "hard break  ", "next", "", "" })
eq(save(), { "hard break  ", "next", "", "" }, "Markdown spaces and blank lines survive saving")
edit("context.diff", { " context  ", " " })
eq(save(), { " context  ", " " }, "patch whitespace survives saving")

edit("trim.txt", { "alpha  ", "beta", "gamma\t", "", "" })
local ns = vim.api.nvim_create_namespace("save-regression")
local prefix_mark = vim.api.nvim_buf_set_extmark(0, ns, 0, 2, {})
local line_mark = vim.api.nvim_buf_set_extmark(0, ns, 1, 1, {})
vim.api.nvim_win_set_cursor(0, { 2, 1 })
eq(save(), { "alpha", "beta", "gamma", "", "" }, "only trailing whitespace is removed")
eq(vim.api.nvim_buf_get_extmark_by_id(0, ns, prefix_mark, {}), { 0, 2 }, "marks in an edited prefix stay put")
eq(vim.api.nvim_buf_get_extmark_by_id(0, ns, line_mark, {}), { 1, 1 }, "marks on other lines stay put")
eq(vim.api.nvim_win_get_cursor(0), { 2, 1 }, "save preserves cursor position")

edit("opt-out.txt", { "keep  " })
vim.b.ravy_trim_whitespace = false
eq(save(), { "keep  " }, "buffer opt-out preserves whitespace")

vim.fn.writefile({ "root = true", "[keep.txt]", "trim_trailing_whitespace = false",
  "[trim.md]", "trim_trailing_whitespace = true" }, root .. "/.editorconfig")
edit("keep.txt", { "project choice  " })
eq(save(), { "project choice  " }, "EditorConfig false overrides cleanup")
edit("trim.md", { "project choice  " })
eq(save(), { "project choice" }, "EditorConfig true owns cleanup, including Markdown")

local text = "中文测试"
edit("utf8.txt")
eq(vim.api.nvim_get_current_line(), text, "UTF-8 is read correctly")
edit("bom.txt")
eq(vim.api.nvim_get_current_line(), text, "Unicode BOM is detected before fallback encodings")
vim.cmd("edit ++enc=gbk " .. vim.fn.fnameescape(root .. "/legacy.txt"))
eq(vim.api.nvim_get_current_line(), text, "legacy encodings remain available explicitly")
vim.cmd("edit ++enc=utf-16le " .. vim.fn.fnameescape(root .. "/no-bom.txt"))
eq(vim.api.nvim_get_current_line(), text, "BOM-less UTF-16 can be selected explicitly")
