vim.opt.spelllang = "en_gb"
vim.opt.spell = true

local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

parser_config.stim = {
  install_info = {
    url = "/Users/andrewpatterson/stim-tresitter/", -- Local path to this repository
    files = {"src/parser.c"},
    branch = "main",
    generate_requires_npm = false,
    requires_generate_from_grammar = true,
  },
  filetype = "stim",
}

require('nvim-treesitter.configs').setup({
  ensure_installed = {
    -- your other parsers...
  },

  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  auto_install = false,  -- Prevent conflicts

    -- Explicitly configure stim
    parser_install_dir = vim.fn.stdpath("data") .. "/tree-sitter-parsers",
  })

  -- Force reload stim filetype
vim.treesitter.language.register("stim", "stim")
vim.filetype.add({
  extension = {
    stim = 'stim',
  },
  filename = {
    ['*.stim'] = 'stim',
  },
})
package.path = package.path .. ';/Users/andrewpatterson/stim-treesitter/?.lua'
-- local ok, result = pcall(function()
--       return loadfile('/Users/andrewpatterson/stim-tresitter/stim-treesitter.lua')
--   end)
--
--   if ok and result then
--       print("File found and loadable")
--       local module = result()
--       print("Module type:", type(module))
--
--       if module then
--           print("Module contents:")
--           for k, v in pairs(module) do
--               print("  " .. k .. ": " .. type(v))
--           end
--
--           if module.setup then
--               print("Setup function found, calling it...")
--               module.setup()
--               print("Setup completed successfully")
--           else
--               print("No setup function found in module")
--           end
--       else
--           print("Module is nil")
--       end
--   else
--       print("File not found or not loadable: " .. tostring(result))
--   end
-- Load and setup the plugin
-- require('stim-treesitter').setup()
local stim_treesitter_module = loadfile('/Users/andrewpatterson/stim-tresitter/stim-treesitter.lua')()
  stim_treesitter_module.setup()

-- Optional: Set up keybindings
vim.keymap.set('n', '<leader>si', ':StimInfoTS<CR>', { desc = 'Stim: Show measurement info' })

-- Notebook utilities
vim.api.nvim_create_user_command("NewNotebook", function(opts)
  require("configs.notebook").new_notebook(opts.args)
end, {
  nargs = "?",
  complete = "file",
  desc = "Create a new Jupyter notebook (markdown format)",
})
