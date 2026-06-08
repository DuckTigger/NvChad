-- Disable treesitter for Python files to avoid decoration provider errors
vim.b.ts_highlight = false

-- Disable concealing
vim.opt_local.conceallevel = 0
vim.opt_local.concealcursor = ""

-- Force stop treesitter
local ok, ts_highlight = pcall(require, "vim.treesitter.highlighter")
if ok and ts_highlight then
  pcall(function()
    ts_highlight.active[vim.api.nvim_get_current_buf()] = nil
  end)
end

pcall(vim.treesitter.stop)
