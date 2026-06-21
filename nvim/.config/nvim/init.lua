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
    enabled = true,
  },

  {
    "vhyrro/luarocks.nvim",
    priority = 1000, -- Very high priority is required, luarocks.nvim should run as the first plugin in your config.
    config = true,
    event = "VeryLazy", 
    opts = {
      rocks = { "dkjson" }, -- Le forzamos explícitamente a validar el paquete JSON
    },
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

  {
    "neovim/nvim-lspconfig",
    dependencies = { "folke/lazydev.nvim", "saghen/blink.cmp" },
    config = function()
      -- Extraemos las capacidades asíncronas que maneja blink.cmp
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      
      -- Lista de servidores binarios a registrar de forma masiva
      local servers = {
        lua_ls = { cmd = { "lua-language-server" } },
        gopls = { cmd = { "gopls" } },
        rust_analyzer = { cmd = { "rust-analyzer" } },
        clangd = { cmd = { "clangd" } }
      }

      -- Registramos cada entorno usando la API moderna nativa de Neovim
      for server_name, config in pairs(servers) do
        vim.lsp.config(server_name, {
          cmd = config.cmd,
          capabilities = capabilities,
          -- Aquí puedes añadir opciones específicas ('opts') por servidor si lo necesitas
        })
      end
    end,
  },
  {
    "tpope/vim-fugitive"
  },
  {
    "ibhagwan/fzf-lua",
    enabled = true,
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<CR>",      desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<CR>",  desc = "Live grep" },
    },
    opts = {},
  }
})

-- 3. Configuraciones básicas
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.clipboard = 'unnamedplus' -- Requiere xclip o wl-clipboard en tu sistema Linux
vim.o.termguicolors = true      -- Necesario para que los colores se vean bien (True Color)
vim.o.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.undofile = true
vim.opt.swapfile = false

-- Atajo para ver el error/warning de la línea actual en un panel flotante
vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = "Ver error o warning actual" })
