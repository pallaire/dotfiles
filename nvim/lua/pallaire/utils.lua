function RetabAndClean()
  print('RetabAndClean')
  -- retab following vim setup
  vim.cmd.retab()

  -- remove trailing spaces
  vim.cmd.s {'/\\s\\+$//ge', range = {1,vim.fn.line("$")}}

  -- Toggle highlight search
  vim.opt.hlsearch = false
  vim.opt.hlsearch = true
end


vim.keymap.set("n", "<leader>rc", RetabAndClean)
