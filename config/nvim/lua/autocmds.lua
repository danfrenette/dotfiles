-- ==============================================================================
-- Autocommands
-- ==============================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ==============================================================================
-- Highlight on Yank
-- ==============================================================================

augroup('YankHighlight', { clear = true })
autocmd('TextYankPost', {
  group = 'YankHighlight',
  desc = 'Highlight when yanking text',
  callback = function()
    vim.highlight.on_yank({ higroup = 'IncSearch', timeout = 200 })
  end,
})

-- ==============================================================================
-- File Type Settings
-- ==============================================================================

augroup('FileTypeSettings', { clear = true })

-- Enable filetype detection
vim.cmd('filetype plugin indent on')

-- ==============================================================================
-- Trim Trailing Whitespace
-- ==============================================================================

augroup('TrimWhitespace', { clear = true })
autocmd('BufWritePre', {
  group = 'TrimWhitespace',
  desc = 'Trim trailing whitespace on save',
  pattern = '*',
  callback = function()
    local save_cursor = vim.fn.getpos('.')
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos('.', save_cursor)
  end,
})

-- ==============================================================================
-- Return to Last Position
-- ==============================================================================

augroup('RestoreCursor', { clear = true })
autocmd('BufReadPost', {
  group = 'RestoreCursor',
  desc = 'Return to last edit position when opening files',
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ==============================================================================
-- Terminal Settings
-- ==============================================================================

augroup('TerminalSettings', { clear = true })
autocmd('TermOpen', {
  group = 'TerminalSettings',
  desc = 'Disable line numbers in terminal',
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})
