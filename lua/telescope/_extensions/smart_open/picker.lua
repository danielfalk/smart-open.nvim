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
    ignore_patterns = config.ignore_patterns,
    show_scores = vim.F.if_nil(opts.show_scores, config.show_scores),
    match_algorithm = opts.match_algorithm or config.match_algorithm,
  }, context)
  opts.get_status_text = finder.get_status_text

  picker = pickers.new(opts, {
    prompt_title = "Search Files By Name",
    on_input_filter_cb = function(query_text)
      if opts.space_as_separator and opts.filename_first then
        local first_space_pos = query_text:find(" ")

        if first_space_pos then
          local before_space = query_text:sub(1, first_space_pos)
          local after_space = query_text:sub(first_space_pos + 1)
          query_text = before_space .. after_space:gsub(" ", "/")
        end
      elseif opts.space_as_separator then
        -- Find the position of the last space
        local last_space_pos = query_text:match(".*()%s")

        -- If a space is found, replace all other spaces with slashes
        if last_space_pos then
          local before_last_space = query_text:sub(1, last_space_pos - 1)
          local after_last_space = query_text:sub(last_space_pos + 1)
          query_text = "/" .. before_last_space:gsub(" ", "/") .. " " .. after_last_space
        end
      end

      return { prompt = query_text }
    end,
    attach_mappings = function(_, map)
      actions.select_default:replace(function(prompt_bufnr)
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
        actions.file_edit(prompt_bufnr)
      end)
      map("i", "<C-c>", function()
        local selection = action_state.get_selected_entry()

        if not pcall(function()
          vim.api.nvim_buf_delete(selection.buf, { force = true })
        end) then
          return
        end

        selection.buf = nil

        -- Now that the buffer is deleted, refresh the entry to reflect it
        local original_selection_strategy = picker.selection_strategy
        picker.selection_strategy = "row"
        picker:refresh(finder)
        vim.defer_fn(function()
          picker.selection_strategy = original_selection_strategy
        end, 50)
      end)
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
