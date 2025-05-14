print("base.lua")

-- vim.cmd('autocmd!')

-- Setting SPACE as the <leader>
vim.g.mapleader = " "

vim.scriptencoding = 'utf-8'
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'

vim.wo.number = true
vim.opt.title = true

-- Tab and indent
vim.opt.autoindent = true
vim.opt.breakindent = true 
vim.opt.expandtab = true
vim.opt.shiftwidth = 2 
vim.opt.smartindent = true -- Smart Indent
vim.opt.smarttab = true
vim.opt.softtabstop = 2
vim.opt.tabstop = 2 

vim.opt.backup = false
vim.opt.backupskip = '/tmp/*'

vim.opt.cmdheight = 1
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.laststatus = 2
vim.opt.scrolloff = 10
vim.opt.shell = 'zsh'
vim.opt.showcmd = true

vim.opt.inccommand = 'split'
vim.opt.ignorecase = true 

vim.opt.wrap = false 
vim.opt.backspace = 'start,eol,indent' 

vim.opt.path:append { '**' } -- Finding files, searching in all sub directories
-- vim.opt.wildignore:append { '*/node_modules/*' } 

vim.opt.mouse = "a"

vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.winblend = 0
vim.opt.wildoptions = 'pum'
vim.opt.pumblend = 5
vim.opt.background = 'dark'
