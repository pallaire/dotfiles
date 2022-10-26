local vim = vim 

vim.bo.autoindent = true
vim.bo.smartindent = true
vim.bo.swapfile = false

vim.o.backup = false
vim.o.completeopt='menuone,noinsert,noselect'
vim.o.errorbells = false
vim.o.expandtab = true
vim.o.hidden = true
vim.o.incsearch = true
vim.o.shiftwidth = 2
vim.o.showmode = false
vim.o.smartcase = true
vim.o.softtabstop = 2
vim.o.syntax = 'on'
vim.o.tabstop = 2
vim.o.termguicolors = true
vim.o.undodir = vim.fn.stdpath('config') .. '/undodir'
vim.o.undofile = true

vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.signcolumn = 'yes'
vim.wo.wrap = false

vim.g.mapleader = ';'


local key_mapper = function(mode, key, result)
  vim.api.nvim_set_keymap(
    mode,
    key,
    result,
    {noremap = true, silent = true}
  )
end

-- key_mapper('', '<up>', '<nop>')
-- key_mapper('', '<down>', '<nop>')
-- key_mapper('', '<left>', '<nop>')
-- key_mapper('', '<right>', '<nop>')
key_mapper('i', 'jk', '<ESC>')
key_mapper('i', 'JK', '<ESC>')
key_mapper('i', 'jK', '<ESC>')
key_mapper('v', 'jk', '<ESC>')
key_mapper('v', 'JK', '<ESC>')
key_mapper('v', 'jK', '<ESC>')




local execute = vim.api.nvim_command
local fn = vim.fn
-- ensure that packer is installed
local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
    execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
    execute 'packadd packer.nvim'
end
vim.cmd('packadd packer.nvim')
local packer = require'packer'
local util = require'packer.util'
packer.init({
  package_root = util.join_paths(vim.fn.stdpath('data'), 'site', 'pack')
})
--- startup and add configure plugins
packer.startup(function()
  local use = use
  -- add you plugins here like:
  -- use 'neovim/nvim-lspconfig'
  end
)


packer.startup(function()
  local use = use
  use 'nvim-treesitter/nvim-treesitter'
  use 'sheerun/vim-polyglot'
  -- these are optional themes but I hear good things about gloombuddy ;)
  -- colorbuddy allows us to run the gloombuddy theme
  use 'tjdevries/colorbuddy.nvim'
  use 'bkegley/gloombuddy'
  use 'folke/tokyonight.nvim'
  -- sneaking some formatting in here too
  use {'prettier/vim-prettier', run = 'yarn install' }
  end
)

-- vim.g.colors_name = 'tokyonight'
vim.cmd [[ colorscheme tokyonight ]]
