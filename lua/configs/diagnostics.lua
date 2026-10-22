local M = {}

local enabled = true

function M.zen_toggle()
  enabled = not enabled
  if enabled then
    vim.diagnostic.enable()
    vim.lsp.inlay_hint.enable(true)
    vim.notify("Zen mode off — diagnostics visible", vim.log.levels.INFO)
  else
    vim.diagnostic.enable(false)
    vim.lsp.inlay_hint.enable(false)
    vim.notify("Zen mode on — diagnostics hidden", vim.log.levels.INFO)
  end
end

return M
