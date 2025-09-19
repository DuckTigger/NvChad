local autocmd = vim.api.nvim_create_autocmd

-- Auto resize panes when resizing nvim window
-- autocmd("VimResized", {
--   pattern = "*",
--   command = "tabdo wincmd =",
-- })
vim.opt.spelllang = "en_gb"
vim.opt.spell = true
-- local python_config = require("configs.python")
-- python_config.setup()
-- require("../custom/stim-treesitter-config").setup()
