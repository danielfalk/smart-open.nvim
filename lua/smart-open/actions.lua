local action_state = require("telescope.actions.state")

local M = {}

local function make_delete_buffer_action(close_command)
  local close = close_command
    or function(buf)
      return pcall(function()
        vim.api.nvim_buf_delete(buf, { force = true })
      end)
    end

  return function(prompt_bufnr, winid)
    local selection = action_state.get_selected_entry()
    local picker = action_state.get_current_picker(prompt_bufnr)

    local removed = close(selection.buf, picker.original_win_id)

    if not removed then
      return
    end

    -- Now that the buffer is deleted, refresh the entry to reflect it
    local original_selection_strategy = picker.selection_strategy
    picker.selection_strategy = "row"
    picker:refresh()
    vim.defer_fn(function()
      picker.selection_strategy = original_selection_strategy
    end, 50)
  end
end

M.delete_buffer = make_delete_buffer_action()
M.make_delete_buffer_action = make_delete_buffer_action

return M
