-- 1. Bootstrap de lazy.nvim (Esto se mantiene igual)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 2. Lista de Plugins
require("lazy").setup({

  -- Tu plugin de Multicursor
  {
    'mg979/vim-visual-multi',
    branch = 'master',
    init = function()
        vim.g.VM_maps = {
            ['Find Under'] = '<C-n>',
        }
    end
  },

  -- TEMA: Tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = false,    -- Queremos que cargue al inicio
    priority = 1000, -- Alta prioridad para que cargue antes que la interfaz
    config = function()
      -- Aquí puedes cambiar entre: "tokyonight-storm", "tokyonight-night", "tokyonight-day", "tokyonight-moon"
      vim.cmd.colorscheme "tokyonight-night" 
    end,
  },

})

-- 3. Configuraciones básicas
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.clipboard = 'unnamedplus' -- Requiere xclip o wl-clipboard en tu sistema Linux
vim.o.termguicolors = true      -- Necesario para que los colores se vean bien (True Color)
