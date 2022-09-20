local Path = require("plenary.path")
local os_home = vim.loop.os_homedir()
local utils = require("telescope.utils")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")


local function format_filepath(path, filename, opts)
  local original_path = path

  path = Path:new(path):make_relative(opts.cwd)
  -- check relative to home/current
  if vim.startswith(path, os_home) then
    path = "~/" .. Path:new(path):make_relative(os_home)
  elseif path ~= original_path then
    path = path
  end

  path = utils.transform_path({ path_display = { shorten = 16 } }, path)

  local found = filename:find("/", 0, true)
  if found then
    local display, _ = path:gsub("(.+)/([^/]+)/([^/]+)$", " (%1)")
    return filename .. display
  else
    local display, _ = path:gsub("(.+)/([^/]+)$", "%2 (%1)")
    return display
  end
end

local function interp(s, tab)
  return s:gsub("(%b{})", function(w)
    local kf = w:sub(2, -2)
    local key, _, fmt = kf:match("(.+)(:(.+))")
    local val = tab[key] or w
    return string.format(fmt and "%" .. fmt or "", val)
  end)
end

local function score_display(scores)
  local fmt = "{total: 6.1f}:M{match: 6.1f} N{fn: 5.1f} F{frecency: 5.1f} O{open:2.f} P{proximity:2d}/{project:2.f} "
  return interp(fmt, scores)
end

return function(opts)
  return function(entry)
    if not entry.formatted_path then
      local path = format_filepath(entry.path, entry.virtual_name, opts)
      if has_devicons and not opts.disable_devicons then
        local icon = devicons.get_icon(entry.virtual_name, string.match(entry.path, "%a+$"), { default = true })
        path = icon .. " " .. path
      end
      entry.formatted_path = path
    end

    if opts.show_scores then
      local scores = {
        total = entry.relevance > 0 and entry.relevance or entry.base_score,
        match = entry.scores.path,
        fn = entry.scores.virtual_name,
        frecency = entry.scores.frecency,
        recency = entry.scores.recency,
        open = entry.scores.open,
        proximity = entry.scores.proximity,
        project = entry.scores.project,
      }
      return score_display(scores) .. " " .. entry.formatted_path
    end

    return entry.formatted_path
  end
end
