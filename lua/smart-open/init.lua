local DbClient = require("telescope._extensions.smart_open.dbclient")
local default_config = require("telescope._extensions.smart_open.default_config")
local history = require("telescope._extensions.smart_open.history")

local config = vim.tbl_deep_extend("force", {}, default_config)

local function set_config(opt_name, value)
  if value ~= nil then
    config[opt_name] = value
  end
end

return {
  config = config,
  setup = function(ext_config)
    set_config("show_scores", ext_config.show_scores)
    set_config("disable_devicons", ext_config.disable_devicons)
    set_config("ignore_patterns", ext_config.ignore_patterns)
    set_config("match_algorithm", ext_config.match_algorithm)
    set_config("cwd_only", ext_config.cwd_only)
    set_config("space_as_separator", ext_config.space_as_separator)

    config.db_filename = vim.fn.stdpath("data") .. "/smart_open.sqlite3"

    local db = DbClient:new({ path = config.db_filename })
    history:setup(db, config)
  end,
}
