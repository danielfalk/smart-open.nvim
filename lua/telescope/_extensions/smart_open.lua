local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local DbClient = require("telescope._extensions.smart_open.dbclient")
local picker = require("telescope._extensions.smart_open.picker")
local config = require("telescope._extensions.smart_open.default_config")
local history = require("telescope._extensions.smart_open.history")

local smart_open = function(opts)
  opts = opts or {}

  opts.cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())
  opts.current_buffer = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or ""
  opts.alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or ""

  opts.config = config

  opts.db = DbClient:new({ path = config.db_filename })

  picker.start(opts)
end

local function set_config(opt_name, value)
  if value ~= nil then
    config[opt_name] = value
  end
end

local health_ok = vim.fn["health#report_ok"]
local health_error = vim.fn["health#report_error"]

local function checkhealth()
  local has_sql, _ = pcall(require, "sql")
  if has_sql then
    health_ok("sql.nvim installed.")
  else
    health_error("sql.nvim NOT installed")
  end
end

return telescope.register_extension({
  setup = function(ext_config)
    set_config("show_scores", ext_config.show_scores)
    set_config("disable_devicons", ext_config.disable_devicons)
    set_config("ignore_patterns", ext_config.ignore_patterns)
    set_config("max_unindexed", ext_config.max_unindexed)

    config.db_filename = vim.fn.stdpath("data") .. "/smart_open.sqlite3"

    local db = DbClient:new({ path = config.db_filename })
    history:setup(db, config)
  end,

  exports = {
    smart_open = smart_open,
    health = checkhealth,
  },
})
