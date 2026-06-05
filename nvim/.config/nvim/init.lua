-- 1. Bootstrap de lazy.nvim
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
  rocks = {
    enabled = false, -- Desactiva LuaRocks por completo en Lazy
  },

  {
  "vhyrro/luarocks.nvim",
  priority = 1000, -- Very high priority is required, luarocks.nvim should run as the first plugin in your config.
  config = true,
  },

  -- Plugin de Multicursor
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

  -- Lazydev: Prepara el entorno para que Neovim y Hyprland entiendan Lua
  {
    "folke/lazydev.nvim",
    ft = "lua", -- Solo se activa al abrir archivos .lua
    opts = {
      library = {
        -- Carga stubs internos de Neovim v0.10+ para vim.uv
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        -- Enlaza los stubs oficiales de Hyprland para autocompletar 'HL' y 'hyprland'
        { path = "/usr/share/hypr/stubs", words = { "hyprland", "HL" } },
      },
    },
  },

  -- Blink.cmp: Motor de autocompletado interactivo de última generación
  {
    'saghen/blink.cmp',
    dependencies = 'rafamadriz/friendly-snippets', -- Trae snippets comunes de código
    version = '*', -- Descarga la última versión estable compilada
    opts = {
      -- Configuración de atajos de teclado para el menú
      keymap = {
        preset = 'default',
        -- 'Enter' confirma la selección, 'Ctrl + Space' fuerza abrir el menú
      },

      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono'
      },

      -- Indica a blink que use las fuentes del LSP nativo (lua_ls)
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
    },
  },

  -- Modificamos nvim-lspconfig para que use las capacidades de blink
  {
    "neovim/nvim-lspconfig",
    dependencies = { "folke/lazydev.nvim", "saghen/blink.cmp" },
    config = function()
      -- Le pasamos a lspconfig las capacidades visuales que maneja blink.cmp
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      require("lspconfig").lua_ls.setup({ capabilities = capabilities })
    end,
  },
})

-- 3. Configuraciones básicas
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.clipboard = 'unnamedplus' -- Requiere xclip o wl-clipboard en tu sistema Linux
vim.o.termguicolors = true      -- Necesario para que los colores se vean bien (True Color)

-- Atajo para ver el error/warning de la línea actual en un panel flotante
vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = "Ver error o warning actual" })
