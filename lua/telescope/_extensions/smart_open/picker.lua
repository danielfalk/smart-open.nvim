local pickers = require("telescope.pickers")
local get_buffer_list = require("telescope._extensions.smart_open.buffers")
local sorters = require("telescope.sorters")
local weights = require("telescope._extensions.smart_open.weights")
local Finder = require("telescope._extensions.smart_open.finder.finder")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local telescope_config = require("telescope.config").values
local history = require("telescope._extensions.smart_open.history")
local make_display = require("telescope._extensions.smart_open.display.make_display")
local smart_open_actions = require("smart-open.actions")

local picker
local M = {}

function M.start(opts)
  local db = opts.db
  local config = opts.config

  ---@diagnostic disable-next-line: param-type-mismatch
  local current = vim.fn.bufnr("%") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("%")) or ""

  local context = {
    cwd = opts.cwd,
    current_buffer = current,
    ---@diagnostic disable-next-line: param-type-mismatch
    alternate_buffer = vim.fn.bufnr("#") > 0 and vim.api.nvim_buf_get_name(vim.fn.bufnr("#")) or "",
    open_buffers = get_buffer_list(),
    weights = db:get_weights(weights.default_weights),
    path_display = opts.path_display,
  }

  local finder = Finder(history, {
    display = make_display(opts),
    cwd = opts.cwd,
    cwd_only = vim.F.if_nil(opts.cwd_only, config.cwd_only),
    ignore_patterns = vim.F.if_nil(opts.ignore_patterns, config.ignore_patterns),
    show_scores = vim.F.if_nil(opts.show_scores, config.show_scores),
    match_algorithm = opts.match_algorithm or config.match_algorithm,
    result_limit = vim.F.if_nil(opts.result_limit, config.result_limit),
  }, context)
  opts.get_status_text = finder.get_status_text

  picker = pickers.new(opts, {
    prompt_title = "Search Files By Name",
    on_input_filter_cb = function(query_text)
      return { prompt = query_text }
    end,
    attach_mappings = function(_, map)
      actions.select_default:enhance({
        pre = function(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if not selection then
            actions.close(prompt_bufnr)
            return
          end
          if current ~= selection.path then
            history:record_usage(selection.path, true)
          end
          local original_weights = db:get_weights(weights.default_weights)
          local revised_weights = weights.revise_weights(original_weights, finder.results, selection)
          db:save_weights(revised_weights)
        end,
      })

      local applied_mappings = { n = {}, i = {} }

      if config.mappings then
        for mode, mode_map in pairs(config.mappings) do
          mode = string.lower(mode)

          for key_bind, key_func in pairs(mode_map) do
            local key_bind_internal = vim.api.nvim_replace_termcodes(key_bind, true, true, true)

            applied_mappings[mode][key_bind_internal] = true

            map(mode, key_bind, key_func)
          end
        end
      end

      local default_close_buffer_keybind = "<C-D>"
      local key_bind_internal = vim.api.nvim_replace_termcodes(default_close_buffer_keybind, true, true, true)

      if not applied_mappings.i[key_bind_internal] then
        map("i", default_close_buffer_keybind, smart_open_actions.delete_buffer)
      end

      return true
    end,
    finder = finder,
    previewer = telescope_config.file_previewer(opts),
    sorter = sorters.Sorter:new({
      -- Just reverse the relevance values for sorting
      scoring_function = function(_, _, x)
        return -x
      end,
    }),
    tiebreak = function(a, b)
      return #a.path < #b.path
    end,
  })
  picker:find()

  vim.api.nvim_buf_set_option(picker.prompt_bufnr, "filetype", "TelescopePrompt")
end
return M
