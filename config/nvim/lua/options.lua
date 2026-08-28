-- ==============================================================================
-- Options
-- ==============================================================================

local opt = vim.opt

-- ==============================================================================
-- UI
-- ==============================================================================

opt.number = true              -- Show line numbers
opt.relativenumber = true      -- Relative line numbers
opt.cursorline = true          -- Highlight current line
opt.signcolumn = 'yes:1'       -- Always show sign column
opt.showmode = false           -- Don't show mode (shown in statusline)
opt.scrolloff = 10             -- Keep 10 lines above/below cursor
opt.termguicolors = true       -- True color support

-- ==============================================================================
-- Editing
-- ==============================================================================

opt.expandtab = true           -- Use spaces instead of tabs
opt.shiftwidth = 2             -- Indent by 2 spaces
opt.tabstop = 2                -- Tab = 2 spaces
opt.smartindent = true         -- Smart auto-indent
opt.linebreak = true           -- Wrap at word boundaries

-- ==============================================================================
-- Search
-- ==============================================================================

opt.ignorecase = true          -- Ignore case in search
opt.smartcase = true           -- Unless uppercase is used
opt.inccommand = 'split'       -- Live preview of substitutions

-- ==============================================================================
-- Splits
-- ==============================================================================

opt.splitbelow = true          -- Horizontal splits below
opt.splitright = true          -- Vertical splits to the right

-- ==============================================================================
-- Behavior
-- ==============================================================================

opt.mouse = 'a'                -- Enable mouse
opt.completeopt = { 'menu', 'menuone', 'noselect' }
opt.shortmess:append('c')      -- Don't show completion messages
opt.updatetime = 250           -- Faster updates
opt.timeoutlen = 300           -- Faster key sequence timeout

-- ==============================================================================
-- Files
-- ==============================================================================

opt.swapfile = false           -- No swap files
opt.undofile = true            -- Persistent undo
opt.undodir = vim.fn.expand('~/.config/nvim/undo/')

-- Create undo directory if it doesn't exist
if vim.fn.isdirectory(vim.fn.expand('~/.config/nvim/undo')) == 0 then
  vim.fn.mkdir(vim.fn.expand('~/.config/nvim/undo'), 'p')
end

-- ==============================================================================
-- Display
-- ==============================================================================

opt.list = true                -- Show whitespace characters
opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
opt.fillchars:append('vert:│') -- Vertical split character
opt.showmatch = true           -- Highlight matching brackets
opt.matchtime = 0              -- No delay for matchparen
opt.synmaxcol = 180            -- Don't syntax highlight long lines

-- ==============================================================================
-- Folding
-- ==============================================================================

opt.foldenable = false         -- Disable folding by default

-- ==============================================================================
-- Command line
-- ==============================================================================

opt.wildignorecase = true      -- Case insensitive completion

-- ==============================================================================
-- Diff
-- ==============================================================================

opt.diffopt:append({ 'algorithm:histogram', 'vertical' })

-- ==============================================================================
-- Misc
-- ==============================================================================

opt.backupcopy = 'yes'         -- Keep original file attributes

-- Tags
opt.tags:prepend('.git/tags')

-- Clipboard in codespaces
if os.getenv('CODESPACES') then
  vim.g.clipboard = {
    name = 'rdm',
    copy = { ['+'] = { 'rdm', 'copy' }, ['*'] = { 'rdm', 'copy' } },
    paste = { ['+'] = { 'rdm', 'paste' }, ['*'] = { 'rdm', 'paste' } },
  }
end
