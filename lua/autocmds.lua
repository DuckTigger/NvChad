require "nvchad.autocmds"

-- Disable treesitter for Python files to prevent decoration provider errors
vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
  pattern = "*.py",
  callback = function(args)
    vim.schedule(function()
      pcall(vim.treesitter.stop, args.buf)
    end)
  end,
})
