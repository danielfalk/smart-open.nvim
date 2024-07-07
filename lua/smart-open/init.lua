local DbClient = require("telescope._extensions.smart_open.dbclient")
local default_config = require("telescope._extensions.smart_open.default_config")
local history = require("telescope._extensions.smart_open.history")

local config = vim.tbl_deep_extend("force", {}, default_config)

local function set_config(opt_name, value)
  if value ~= nil then
    config[opt_name] = value
  end
end

local db_by_path = {}

return {
  config = config,
  setup = function(ext_config)
    set_config("show_scores", ext_config.show_scores)
    set_config("disable_devicons", ext_config.disable_devicons)
    set_config("ignore_patterns", ext_config.ignore_patterns)
    set_config("match_algorithm", ext_config.match_algorithm)
    set_config("cwd_only", ext_config.cwd_only)
    set_config("buffer_indicators", ext_config.buffer_indicators)
    set_config("mappings", ext_config.mappings)
    set_config("result_limit", ext_config.result_limit)
    set_config("hidden", ext_config.hidden)
    set_config("no_ignore", ext_config.no_ignore)
    set_config("no_ignore_parent", ext_config.no_ignore_parent)
    set_config("follow", ext_config.follow)

    config.db_filename = vim.fn.stdpath("data") .. "/smart_open.sqlite3"

    db_by_path[config.db_filename] = db_by_path[config.db_filename] or DbClient:new({ path = config.db_filename })

    history:setup(db_by_path[config.db_filename], config)
  end,
}
