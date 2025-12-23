-- ==============================================================================
-- Neovim Configuration
-- ==============================================================================

-- Leader key (must be set before plugins)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load configuration modules
require('options')
require('plugins')
require('keymaps')
require('autocmds')
