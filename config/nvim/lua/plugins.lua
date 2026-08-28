-- ==============================================================================
-- Plugins (vim-plug)
-- ==============================================================================

local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.config/nvim/bundle')

-- tpope utilities
Plug('tpope/vim-eunuch')           -- Unix commands
Plug('tpope/vim-endwise')          -- Auto-end structures
Plug('tpope/vim-fugitive')         -- Git integration
Plug('tpope/vim-rails')            -- Rails utilities
Plug('tpope/vim-repeat')           -- Repeat plugin commands
Plug('tpope/vim-rhubarb')          -- GitHub integration
Plug('tpope/vim-surround')         -- Surround text objects
Plug('tpope/vim-vinegar')          -- Enhanced netrw
Plug('tpope/vim-projectionist')    -- Project navigation
Plug('tpope/vim-commentary')       -- Comment code

-- QoL
Plug('christoomey/vim-tmux-navigator')  -- Tmux integration
Plug('BlakeWilliams/vim-pry')           -- Pry debugging
Plug('github/copilot.vim')              -- GitHub Copilot
Plug('wsdjeg/vim-fetch')                -- Open file:line:col

-- Colors / Theme
Plug('nanotech/jellybeans.vim')

-- Testing
Plug('vim-test/vim-test')

-- Searching
Plug('mhinz/vim-grepper')

vim.call('plug#end')

-- ==============================================================================
-- Plugin Configuration
-- ==============================================================================

-- Jellybeans colorscheme
vim.cmd('colorscheme jellybeans')

-- netrw (vinegar)
vim.g.netrw_bufsettings = 'noma nomod nu nobl nowrap ro nonumber'
vim.g.netrw_list_hide = [[\(^\|\s\s\)\zs\.\S\+]]
vim.g.netrw_retmap = 1
vim.g.netrw_fastbrowse = 0
vim.g.netrw_dirhistmax = 0

-- vim-test
vim.g['test#strategy'] = 'neovim'

-- grepper
vim.g.grepper = { tools = { 'rg', 'git' } }

-- tmux navigator
vim.g.tmux_navigator_no_mappings = 1
