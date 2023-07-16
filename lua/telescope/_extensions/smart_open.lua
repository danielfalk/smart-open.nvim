local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local DbClient = require("telescope._extensions.smart_open.dbclient")
local picker = require("telescope._extensions.smart_open.picker")
local config = require("smart-open").config

local smart_open = function(opts)
  opts = opts or {}

  ---@diagnostic disable-next-line: missing-parameter
  opts.cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())
  opts.current_buffer = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or ""
  opts.alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or ""
  opts.filename_first = opts.filename_first == nil and true or opts.filename_first

  opts.config = config

  opts.db = DbClient:new({ path = config.db_filename })

  picker.start(opts)
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
  setup = require("smart-open").setup,
  exports = {
    smart_open = smart_open,
    health = checkhealth,
  },
})
