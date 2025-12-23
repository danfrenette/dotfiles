-- ==============================================================================
-- Keymaps
-- ==============================================================================

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ==============================================================================
-- General
-- ==============================================================================

-- Disable Q and K (useless defaults)
map('n', 'Q', '<Nop>', opts)
map('n', 'K', '<Nop>', opts)

-- Clear search highlight with Escape
map('n', '<Esc>', '<cmd>nohlsearch<CR>', opts)

-- Save and quit
map('n', '<C-s>', '<cmd>w<CR>', opts)
map('n', '<C-x>', '<cmd>q<CR>', opts)

-- Edit file in same directory
map('n', '<leader>e', ':e <C-R>=expand("%:p:h") . "/" <CR>', { noremap = true })

-- Make Y act like other capitals
map('n', 'Y', 'y$', opts)

-- Navigate wrapped lines naturally
map('n', 'j', 'gj', opts)
map('n', 'k', 'gk', opts)

-- Select last pasted/inserted text
map('n', 'gp', '`[v`]', opts)

-- Switch to alternate buffer
map('n', '<leader><space>', '<cmd>e #<CR>', opts)

-- ==============================================================================
-- Splits / Windows
-- ==============================================================================

-- Tmux-aware navigation
map('n', '<C-h>', '<cmd>TmuxNavigateLeft<CR>', opts)
map('n', '<C-j>', '<cmd>TmuxNavigateDown<CR>', opts)
map('n', '<C-k>', '<cmd>TmuxNavigateUp<CR>', opts)
map('n', '<C-l>', '<cmd>TmuxNavigateRight<CR>', opts)

-- ==============================================================================
-- Git (Fugitive)
-- ==============================================================================

map('n', '<leader>gs', '<cmd>Git<CR>', opts)
map('n', '<leader>gc', '<cmd>Git commit<CR>', opts)
map('n', '<leader>gg', '<cmd>GBrowse<CR>', opts)
map('n', '<leader>gb', '<cmd>Git blame<CR>', opts)
map('n', '<leader>gd', '<cmd>Gdiff<CR>', opts)

-- ==============================================================================
-- Testing (vim-test)
-- ==============================================================================

map('n', '<leader>s', '<cmd>TestNearest<CR>', opts)
map('n', '<leader>t', '<cmd>TestFile<CR>', opts)
map('n', '<leader>l', '<cmd>TestLast<CR>', opts)

-- ==============================================================================
-- Rails
-- ==============================================================================

map('n', '<leader>u', '<cmd>A<CR>', opts)  -- Alternate file

-- ==============================================================================
-- Searching
-- ==============================================================================

map('n', '<leader>f', '<cmd>Grepper<CR>', opts)
map('n', '<leader>a', '<cmd>Grepper -tool rg<CR>', opts)

-- ==============================================================================
-- Buffers
-- ==============================================================================

map('n', '<leader>b', '<cmd>Buffers<CR>', opts)

-- ==============================================================================
-- Debugging
-- ==============================================================================

map('n', '<leader>d', 'k:call pry#insert()<CR>', { noremap = true })

-- ==============================================================================
-- Clipboard
-- ==============================================================================

-- Copy to system clipboard in visual mode
map('v', '<C-c>', '"+y', opts)

-- ==============================================================================
-- Terminal
-- ==============================================================================

-- Easy terminal escape
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
