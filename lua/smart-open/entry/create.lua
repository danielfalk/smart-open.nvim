local function calculate_proximity(a, b)
  local in_common = 0
  local index = 0
  local previous_index = 1

  while true do
    local path_separator = package.config:sub(1, 1)
    index = a:find(path_separator, index + 1)
    if not index then
      break
    elseif index > 1 then
      if a:sub(previous_index, index) == b:sub(previous_index, index) then
        in_common = in_common + 1
      else
        break
      end
    end
    previous_index = index
  end

  return in_common
end

local function normalize_proximity(value)
  return 1 - 1 / (1 + math.exp(value * 0.5 - 3))
end

--- Creates an entry with base scoring data
---@param path string:
---@param history table:
--- * frecency number
--- * recent_rank number
---@param context table:
--- * cwd string
--- * current_buffer string
--- * alternate_buffer string
--- * open_buffers table
--- * weights table
local function create_entry_data(path, history, context)
  local weights = context.weights

  local scores = {
    open = 0,
    alt = 0,
    proximity = 0,
    project = 0,
    frecency = 0,
    recency = 0,
  }

  local entry = {
    path = path,
    scores = scores,
    base_score = 0,
    current = path == context.current_buffer,
    modified = false,
  }

  if not entry.current then
    if path == context.alternate_buffer then
      scores.alt = weights.alt
    end

    local loaded = context.open_buffers[path]
    if loaded then
      if loaded.bufnr then
        entry.buf = loaded.bufnr
        entry.modified = loaded.is_modified
      end
      scores.open = weights.open
    end

    scores.frecency = weights.frecency * history.frecency
    if history.recent_rank and history.recent_rank > 0 then
      scores.recency = weights.recency * (8 / (history.recent_rank + 7))
    end

    local dir = (context.current_buffer == "" or context.current_buffer == nil) and context.cwd
      or context.current_buffer

    local prox = calculate_proximity(dir, path)
    scores.proximity = weights.proximity * normalize_proximity(prox)
  end

  if path:sub(1, #context.cwd) == context.cwd then
    scores.project = weights.project
  end

  for _, v in pairs(scores) do
    entry.base_score = entry.base_score + v
  end

  return entry
end

return create_entry_data
