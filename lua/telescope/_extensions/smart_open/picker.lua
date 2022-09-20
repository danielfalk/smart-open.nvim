local pickers = require("telescope.pickers")
local get_buffer_list = require("telescope._extensions.smart_open.buffers")
local make_entry_maker = require("telescope._extensions.smart_open.display.entry_maker")
local sorters = require("telescope.sorters")
local weights = require("telescope._extensions.smart_open.weights")
local Finder = require("telescope._extensions.smart_open.finder.finder")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local telescope_config = require("telescope.config").values
local history = require("telescope._extensions.smart_open.history")

local picker
local M = {}

function M.start(opts)
  local db = opts.db
  local config = opts.config
  local buffers = get_buffer_list()
  local entry_maker = make_entry_maker({
    cwd = opts.cwd,
    current_buffer = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or "",
    alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or "",
    show_scores = opts.show_scores,
    buf_is_loaded = function(buf)
      return buffers[buf]
    end,
    weights = db:get_weights(weights.default_weights)
  })

  local finder = Finder(history, {
    entry_maker = entry_maker,
    cwd = opts.cwd,
    cwd_only = opts.cwd_only,
    ignore_patterns = config.ignore_patterns,
    max_unindexed = config.max_unindexed,
  })
  opts.get_status_text = finder.get_status_text

  picker = pickers.new(opts, {
    prompt_title = "Search Files By Name",
    on_input_filter_cb = function(query_text)
      return { prompt = query_text }
    end,
    attach_mappings = function()
      actions.select_default:replace(function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        history:record_usage(selection.path, true)
        local original_weights = db:get_weights(weights.default_weights)
        local revised_weights = weights.revise_weights(original_weights, finder.results, selection)
        db:save_weights(revised_weights)
        actions.file_edit(prompt_bufnr, "edit")
      end)
      return true
    end,
    finder = finder,
    previewer = telescope_config.file_previewer(opts),
    sorter = sorters.highlighter_only(opts),
  })
  picker:find()

  vim.api.nvim_buf_set_option(picker.prompt_bufnr, "filetype", "smart_open")
end
return M

