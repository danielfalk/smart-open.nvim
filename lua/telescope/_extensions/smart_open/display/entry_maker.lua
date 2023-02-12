local make_display = require("telescope._extensions.smart_open.display.make_display")
local utils = require("telescope.utils")

local is_index_filename = {
  ["index.js"] = true,
  ["index.ts"] = true,
  ["index.jsx"] = true,
  ["index.tsx"] = true,
  ["index.test.js"] = true,
  ["index.test.ts"] = true,
  ["index.test.jsx"] = true,
  ["index.test.tsx"] = true,
  ["__init__.py"] = true,
  ["init.lua"] = true,
}

local function parse_filename(path)
  local fn = path:match("([^/]+)$")
  if is_index_filename[fn] then
    fn = path:match("([^/]+/[^/]+)$") or path
  end

  return fn
end

local function calculate_proximity(a, b)
  local a_parts = utils.max_split(a, "/")
  local b_parts = utils.max_split(b, "/")
  local in_common = 0
  for index, a_part in pairs(a_parts) do
    if index < #b_parts and a_part == b_parts[index] then
      in_common = in_common + 1
    end
  end
  return in_common
end

local function normalize_proximity(value)
  return 1 - 1 / (1 + math.exp(value * .5 - 3))
end

--- Creates an entry maker
---@param opts table: Finder options...
--- * cwd string
--- * current_buffer string
--- * alternate_buffer string
--- * buf_is_loaded function
--- * weights table
--- * show_scores boolean: Show scores for informational purposes
return function(opts)
  local display = make_display(opts)
  local weights = opts.weights

  --- make_entry
  --- Creates entries with all the scoring data that can be determined before
  --- the user types anything
  ---@param record object:
  ---@param max_frecency_score number
  return function(record, max_frecency_score)
    local line = record.path

    local scores = {
      open = 0,
      alt = 0,
      proximity = 0,
      project = 0,
      frecency = 0,
      recency = 0,
      virtual_name_fzy = 0, -- filled in when prompt relevance is calculated
      virtual_name_fzf = 0, -- filled in when prompt relevance is calculated
      path_fzy = 0, -- filled in when prompt relevance is calculated
      path_fzf = 0, -- filled in when prompt relevance is calculated
    }

    local entry = {
      virtual_name = parse_filename(record.path),
      path = record.path,
      display = display, -- this will get overwritten when filtering anyway
      ordinal = record.path, -- this will get overwritten when filtering as well
      scores = scores,
      base_score = 0,
      relevance = 0,
      formatted_path = nil,
      current = line == opts.current_buffer,
    }

    if not entry.current then
      if line == opts.alternate_buffer then
        scores.alt = weights.alt
      end
      if opts.buf_is_loaded(line) then
        scores.open = weights.open
      end

      scores.frecency = weights.frecency * (record.score / max_frecency_score)

      if record.recent_rank then
        scores.recency = weights.recency * (8 / (record.recent_rank + 7))
      end

      local dir = (opts.current_buffer == "" or opts.current_buffer == nil) and opts.cwd or opts.current_buffer
      scores.proximity = weights.proximity * normalize_proximity(calculate_proximity(dir, line))
    end

    if line:sub(1, #opts.cwd) == opts.cwd then
      -- Extra points if under the working directory (this is assumed to be a project dir)
      scores.project = weights.project
    end

    for _, v in pairs(scores) do
      entry.base_score = entry.base_score + v
    end

    return entry
  end
end
