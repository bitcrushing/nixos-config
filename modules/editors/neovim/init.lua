-- LazyVim. Plugins are managed by lazy.nvim at runtime (~/.local/share/nvim),
-- not by Nix. LSP servers come from Nix instead of mason; see
-- modules/editors/tooling.nix.

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- Rosé Pine Moon, matching the stylix scheme (modules/theme.nix). The
    -- transparent background lets ghostty's translucency and blur show.
    {
      "rose-pine/neovim",
      name = "rose-pine",
      opts = { variant = "moon", styles = { transparency = true } },
    },
    { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "rose-pine" } },
    -- Status line: rose-pine's own lualine theme paints normal mode (and the
    -- clock, which follows the mode colour) in pink "rose". Use a muted block
    -- for normal mode and keep tinted accents for the other modes.
    {
      "nvim-lualine/lualine.nvim",
      opts = function(_, opts)
        local p = require("rose-pine.palette")
        local function mode(bg, fg)
          return {
            a = { bg = bg, fg = fg, gui = "bold" },
            b = { bg = p.overlay, fg = p.text },
            c = { bg = p.none, fg = p.subtle },
          }
        end
        opts.options.theme = {
          normal = mode(p.muted, p.text),
          insert = mode(p.pine, p.text),
          visual = mode(p.iris, p.base),
          replace = mode(p.love, p.base),
          command = mode(p.gold, p.base),
          inactive = mode(p.overlay, p.subtle),
        }
      end,
    },
    { import = "lazyvim.plugins.extras.lang.ocaml" },
    {
      "neovim/nvim-lspconfig",
      opts = {
        servers = {
          -- Never let mason install these (it can't without npm).
          bashls = { mason = false }, -- from tooling.nix
          ocamllsp = { mason = false }, -- not installed globally; needs a project shell
        },
      },
    },
  },
  defaults = {
    lazy = false,
    version = false, -- always use the latest git commit
  },
  checker = { enabled = true }, -- check for plugin updates
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
