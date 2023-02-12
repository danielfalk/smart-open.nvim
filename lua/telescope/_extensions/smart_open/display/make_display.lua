local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local format_filepath = require("telescope._extensions.smart_open.display.format_filepath")
local util = require("telescope._extensions.smart_open.util")

local function interp(s, tab)
  return s:gsub("(%b{})", function(w)
    local kf = w:sub(2, -2)
    local key, _, fmt = kf:match("(.+)(:(.+))")
    local val = tab[key] or w
    return string.format(fmt and "%" .. fmt or "", val)
  end)
end

local function score_display(entry)
  local scores = {
    total = entry.relevance > 0 and entry.relevance or entry.base_score,
    match = entry.scores.path_fzy + entry.scores.path_fzf,
    fn = entry.scores.virtual_name_fzy + entry.scores.virtual_name_fzf,
    frecency = entry.scores.frecency,
    recency = entry.scores.recency,
    open = entry.scores.open,
    proximity = entry.scores.proximity,
    project = entry.scores.project,
  }

  local fmt = "{total: 6.1f}:M{match: 6.1f} N{fn: 5.1f} F{frecency: 5.1f} O{open:2.f} P{proximity:2d}/{project:2.f} "
  return interp(fmt, scores)
end

return function(opts) -- make_display
  local results_width = nil

  local filename_opts = {
    cwd = opts.cwd,
    filename_first = true,
    shorten_to = 0,
  }

  local function update_results_width()
    if results_width then
      return results_width
    end
    local status = require("telescope.state").get_status(vim.api.nvim_get_current_buf())
    results_width = vim.api.nvim_win_get_width(status.results_win)
  end

  return function(entry) -- display
    update_results_width()

    if not entry.formatted_path then
      local path_room = results_width - 5
      local path, path_hl = format_filepath(entry.path, entry.virtual_name, filename_opts, path_room)
      if has_devicons and not opts.disable_devicons then
        local icon, hl_group =
          devicons.get_icon(entry.virtual_name, string.match(entry.path, "%a+$"), { default = true })
        path = icon .. " " .. path
        entry.formatted_path = {
          path,
          entry.current and { { { 1, results_width }, "Comment" } } or {
            { { 1, 3 }, hl_group },
            util.shift_hl(path_hl, 3),
          },
        }
      else
        entry.formatted_path = { path }
      end
    end

    if opts.show_scores then
      if has_devicons and not opts.disable_devicons then
        local sd = score_display(entry) .. " "
        return sd .. entry.formatted_path[1],
          {
            { { #sd + 1, #sd + 3 }, entry.formatted_path[2][1][2] },
            { { #sd + 4 + #entry.virtual_name, #sd + #entry.formatted_path[1] }, "Directory" },
          }
      else
        return score_display(entry) .. " " .. entry.formatted_path[1]
      end
    end

    return unpack(entry.formatted_path)
  end
end
