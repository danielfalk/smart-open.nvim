local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local format_filepath = require("telescope._extensions.smart_open.display.format_filepath")
local sum = require("smart-open.util.table").sum
local combine_display = require("smart-open.util.combine_display")

local function interp(s, tab)
  return s:gsub("(%b{})", function(w)
    local kf = w:sub(2, -2)
    local key, _, fmt = kf:match("(.+)(:(.+))")
    local val = tab[key] or w
    return string.format(fmt and "%" .. fmt or "", val)
  end)
end

local function open_buffer_indicators(entry, buffer_indicators)
  local prefix = "  "

  if entry.buf and vim.api.nvim_buf_is_valid(entry.buf) then
    if entry.scores.alt > 0 then
      prefix = buffer_indicators.previous .. " "
    else
      prefix = buffer_indicators.others .. " "
    end
  end

  return { prefix }
end

local function score_display(entry)
  local scores = {
    total = (entry.relevance or 0) > 0 and entry.relevance or entry.base_score,
    match = (entry.scores.path_fzy or 0) + (entry.scores.path_fzf or 0),
    fn = (entry.scores.virtual_name_fzy or 0) + (entry.scores.virtual_name_fzf or 0),
    frecency = entry.scores.frecency,
    recency = entry.scores.recency,
    open = entry.scores.open,
    proximity = entry.scores.proximity,
    project = entry.scores.project,
  }

  local fmt = "{total: 6.1f}:M{match: 6.1f} N{fn: 5.1f} F{frecency: 5.1f} "
    .. "R{recency:4.1f} O{open:2.f} P{proximity:2d}/{project:2.f} "
  return interp(fmt, scores)
end

local function make_display(opts)
  local results_width = nil

  local filename_opts = {
    cwd = opts.cwd,
    filename_first = opts.filename_first,
    shorten_to = 0,
  }

  local function update_results_width()
    if results_width then
      return results_width
    end
    local status = require("telescope.state").get_status(vim.api.nvim_get_current_buf())
    results_width = vim.api.nvim_win_get_width(status.results_win)
  end

  local highlight
  if opts.match_algorithm == "fzf" then
    local get_fzf_sorter = require("smart-open.matching.algorithms.fzf_implementation")
    local fzf_sorter = get_fzf_sorter({
      case_mode = "smart_case",
      fuzzy = true,
    })
    highlight = fzf_sorter
  else
    highlight = require("telescope.sorters").get_fzy_sorter(opts)
  end

  local function format(entry, fit_width)
    local hl_group = {}
    local display, path_hl = format_filepath(entry.path, entry.virtual_name, filename_opts, fit_width)

    -- This is the point at which the directory itself starts.  This is because we're putting the virtual_name first.
    local split_pos = #entry.virtual_name

    local path
    if filename_opts.filename_first then
      -- Transpose order to canonical path order.
      local spacing = 1
      path = display:sub(#entry.virtual_name + spacing + 1) .. "/" .. entry.virtual_name
    else
      path = display
    end

    local hl = highlight:highlighter(entry.prompt, path)

    if entry.current then
      table.insert(hl_group, { { 0, fit_width }, "Comment" })
    elseif not vim.tbl_isempty(path_hl) then
      table.insert(hl_group, path_hl)
    end

    if hl then
      for _, v in ipairs(hl) do
        local n
        if filename_opts.filename_first then
          n = v + split_pos
          if n > #path then
            n = n - (#path + 1)
          end
        else
          n = v - 1
        end
        table.insert(hl_group, { { n, n + 1 }, "TelescopeMatching" })
      end
    end

    return { display, hl_group = hl_group }
  end

  local function display(entry)
    update_results_width()

    local to_display = {}

    if opts.show_scores then
      table.insert(to_display, { score_display(entry) .. " " })
    end

    table.insert(
      to_display,
      open_buffer_indicators(entry, opts.open_buffer_indicators or opts.config.open_buffer_indicators)
    )

    if has_devicons and not opts.disable_devicons then
      local icon, hl_group = devicons.get_icon(entry.virtual_name, string.match(entry.path, "%a+$"), { default = true })
      table.insert(to_display, {
        icon .. " ",
        hl_group = hl_group and { { { 0, #icon + 1 }, hl_group } },
      })
    end

    local used = sum(vim.tbl_map(function(d)
      return vim.fn.strdisplaywidth(d[1])
    end, to_display))

    local fit_width = results_width - used

    table.insert(to_display, format(entry, fit_width))

    local result = combine_display(to_display)

    return result[1], result.hl_group
  end

  return display
end

return make_display
