local Path = require("plenary.path")
local os_home = vim.loop.os_homedir()
local len = vim.fn.strdisplaywidth
local table_util = require("smart-open.util.table")
local max = table_util.max
local sum = table_util.sum

local function fit_dir(path, available, opts)
  if len(path) <= available then
    return path
  end

  local segments = vim.split(path, "/", {})
  local segment_limits = vim.tbl_map(function(segment)
    return len(segment)
  end, segments)

  local min_limit = opts.shorten_to or 0

  for segment_limit = max(segment_limits), min_limit, -1 do
    if segment_limit == 0 then
      return "…"
    end
    for i, v in ipairs(segment_limits) do
      segment_limits[i] = math.min(v, segment_limit)
      if sum(segment_limits) + (#segments - 1) == available then
        goto continue
      end
    end
  end

  ::continue::

  for i, segment in ipairs(segments) do
    if segment_limits[i] == 1 then
      segments[i] = segment:sub(0, 1)
    elseif len(segment) > segment_limits[i] then
      segments[i] = segment:sub(0, segment_limits[i] - 1) .. "…"
    end
  end

  return table.concat(segments, "/")
end

-- normalize_path ensures that the path is displayed as relative when path is under cwd,
-- and is otherwise displayed prepended with ~ when under the home directory
-- and finally displayed as absolute in all other cases
local function normalize_path(path, cwd)
  local p = Path:new(path)
  local abspath = p:absolute(cwd)
  if vim.startswith(abspath, os_home) and not vim.startswith(cwd, os_home) then
    return "~/" .. p:make_relative(os_home)
  else
    path = p:normalize(cwd)
    return path == "." and "" or path
  end
end

local function format_filepath(path, filename, opts, maxlen)
  path = normalize_path(path:sub(1, len(path) - len(filename) - 1), opts.cwd)

  local hl_group = {}

  if opts.filename_first then
    local spacing = " "
    local result = filename .. spacing .. path
    if maxlen and len(result) > maxlen then
      -- There's overflow
      local remaining = maxlen - (len(filename) + len(spacing))

      if remaining < 0 then
        -- There's not even enough space for the filename, so truncate it
        return filename:sub(1, remaining - 1) .. "…", hl_group
      elseif remaining < 2 then
        -- There's just enough space for the filename
        return filename, hl_group
      elseif remaining == 2 then
        return filename .. " …", hl_group
      end

      result = filename .. spacing .. fit_dir(path, remaining, { shorten_to = 8 })
    end
    local start_index = len(filename .. spacing)
    hl_group = { { start_index, start_index + len(result) }, "SmartOpenDirectory" }

    return result, hl_group
  else
    if maxlen and len(path) > maxlen then
      -- There's overflow
      local remaining = maxlen - len(filename)

      if remaining < 0 then
        -- There's not even enough space for the filename, so truncate it
        return filename:sub(1, remaining - 1) .. "…", hl_group
      elseif remaining < 2 then
        -- There's just enough space for the filename
        return filename, hl_group
      elseif remaining == 2 then
        return "…/" .. filename, { { 1, 2 }, "SmartOpenDirectory" }
      end

      path = fit_dir(path, remaining, { shorten_to = 0 })
    end
    if path ~= "" then
      path = path .. "/"
    end
    hl_group = { { 0, len(path) }, "SmartOpenDirectory" }
    return path .. filename, hl_group
  end
end

return format_filepath
