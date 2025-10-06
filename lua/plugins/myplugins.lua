local overrides = require "configs.overrides"
local has_words_before = function()
  unpack = unpack or table.unpack
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
end
local cmp = require "cmp"

---@type NvPluginSpec[]
local plugins = {

  -- Override plugin definition options
  {
		"mfussenegger/nvim-lint",
		event = {
			"BufReadPre",
			"BufNewFile",
		},
		config = function()
			require("configs.lint").setup()
		end,
	},
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require "nvchad.configs.lspconfig"
      require "configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },
  {
    "nvimtools/none-ls.nvim",
    -- event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local none_ls = require("none-ls")
      none_ls.setup(require("configs.none-ls"))
    end,
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      local conf = require "nvchad.configs.cmp"
      conf.mapping["<CR>"] = cmp.mapping {
        i = function(fallback)
          if cmp.visible() and cmp.get_active_entry() then
            cmp.confirm { behavior = cmp.ConfirmBehavior.Replace, select = false }
          else
            fallback()
          end
        end,
        s = cmp.mapping.confirm { select = true },
        c = cmp.mapping.confirm { behavior = cmp.ConfirmBehavior.Replace, select = true },
      }
      conf.mapping["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          local entry = cmp.get_selected_entry()
          if not entry then
            cmp.select_next_item { behavior = cmp.SelectBehavior.Select }
          else
            cmp.confirm()
          end
        elseif require("luasnip").expand_or_jumpable() then
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
        elseif has_words_before() then
          cmp.complete()
        else
          fallback()
        end
      end, {
        "i",
        "s",
        -- "c",
      })
      conf.mapping["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif require("luasnip").jumpable(-1) then
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
        else
          fallback()
        end
      end, {
        "i",
        "s",
      })
      return conf
    end,
  },
  {
    "L3MON4D3/LuaSnip",
    opts = overrides.luasnip,
    config = function()
      require("luasnip.loaders.from_lua").lazy_load { paths = { vim.fn.stdpath "config" .. "/lua/custom/lua_snippets" } }
      require("luasnip.loaders.from_vscode").lazy_load {
        paths = { vim.fn.stdpath "config" .. "/lua/custom/lua_snippets/converted" },
      }
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },

  -- Install a plugin
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },

  {
    "lervag/vimtex",
    lazy = false,
    config = function()
      vim.api.nvim_create_autocmd({ "FileType" }, {
        group = vim.api.nvim_create_augroup("lazyvim_vimtex_conceal", { clear = true }),
        pattern = { "bib", "tex" },
        callback = function()
          vim.wo.conceallevel = 2
        end,
      })
      vim.g.vimtex_mappings_disable = { ["n"] = { "K" } }
      vim.g.vimtex_quickfix_method = vim.fn.executable "pplatex" == 1 and "pplatex" or "latexlog"
      vim.g.tex_flavor = "luatex"
      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_compiler_latexmk = { out_dir = "build" }
      vim.g.vimtex_view_general_viewer = "zathura"
      vim.g.vimtex_viewer_zathura = 1
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_compiler_latexmk_engines = {
        _ = '-lualatex'
      }
      vim.g.vimtex_compiler_latexmk = {
        build_dir = "build",
        aux_dir = "build",
        out_dir = "build",
        options = {
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }
    end,
  },

  {
    "smjonas/snippet-converter.nvim",
    config = function()
      local template = {
        sources = {
          ultisnips = {
            vim.fn.stdpath "config" .. "/lua/custom/lua_snippets/ultisnips",
          },
          snipmate = {
            vim.fn.stdpath "config" .. "/lua/custom/lua_snippets/snippets",
          },
        },
        output = {
          vscode_luasnip = {
            vim.fn.stdpath "config" .. "/lua/custom/lua_snippets/converted",
          },
        },
      }

      require("snippet_converter").setup {
        templates = { template },
      }
    end,
  },
  {
    "preservim/vim-markdown",
    config = function()
      vim.g.vim_markdown_math = 1
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      config = function()
        require("dap-python").setup "~/.virtualenvs/debugpy/bin/python"
        require("dap-python").test_runner = "pytest"
      end,
    },
    config = function()
      local dap = require "dap"
      dap.adapters.python = {
        type = "executable",
        command = "python",
        args = { "-m", "debugpy.adapter" },
      }
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}", -- This will launch the current file
          pythonPath = function()
            return "python"
          end,
        },
      }
      require "configs.python"
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require "configs.dapui"
    end,
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    ft = "python",
    config = function()
      require "configs.neotest"
    end,
    -- config = function()
    --   require("neotest").setup {
    --     adapters = {
    --       require "neotest-python" {
    --         python = vim.fn.expand "python",
    --         root = function()
    --           return vim.fn.getcwd()
    --         end,
    --         dap = { justMyCode = false },
    --         args = { "--log-level", "DEBUG", "--verbose", "-xvs" },
    --         runner = "pytest",
    --         discovery = {
    --           enabled = true,
    --         },
    --         is_test_file = function(filename)
    --           return filename:match "^tests?%.?py$" or filename:match "^test_.+%.py$" or filename:match "%.test_.+%.py$"
    --         end,
    --         pytest_discover_instances = true,
    --       },
    --     },
    --   }
    -- end,
  },
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
    ft = { "python", "javascript", "typescript", "lua" }, -- Add filetypes you need
    opts = {
      enabled = true,
      languages = {
        python = {
          template = {
            annotation_convention = "reST", -- or "google_docstrings" or "reST"
          },
        },
      },
    },
  },
  {
    "github/copilot.vim",
    lazy = false,
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
    end,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    lazy = false,
    -- branch = "canary",
    dependencies = {
      { "nvim-lua/plenary.nvim" },
    },
    build = "make tiktoken",
    opts = {
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      {
        -- model = 3gpt-4.1',           -- AI model to use
        temperature = 0.1,       -- Lower = focused, higher = creative
        window = {
          layout = "vertical",   -- 'vertical', 'horizontal', 'float'
          width = 0.3,           -- 50% of screen width
        },
        auto_insert_mode = true, -- Enter insert mode when opening
      },
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = overrides.telescope,
  },

  -- To make a plugin not be loaded
  -- {
  --   "NvChad/nvim-colorizer.lua",
  --   enabled = false
  -- },

  -- All NvChad plugins are lazy-loaded by default
  -- For a plugin to be loaded, you will need to set either `ft`, `cmd`, `keys`, `event`, or set `lazy = false`
  -- If you want a plugin to load on startup, add `lazy = false` to a plugin spec, for example
  -- {
  --   "mg979/vim-visual-multi",
  --   lazy = false,
  -- }
}

return plugins
