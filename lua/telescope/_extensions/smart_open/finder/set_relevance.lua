local extensions = require("telescope").extensions
local sorters = require("telescope.sorters")
local weights = require("telescope._extensions.smart_open.weights").default_weights

local function normalize_fzy_score(fzy_score)
  -- A negative score means no match
  if fzy_score < 0 then
    return 0
  end
  return 1 - 1 / (1 + math.exp(-10 * (fzy_score * 10 - 0.65)))
end

local ok, sorter = pcall(function () return extensions.fzy_native.native_fzy_sorter() end)
if not ok then
  sorter = sorters.get_fzy_sorter()
end

local function fzy_score(prompt, line, entry)
  return sorter:scoring_function(prompt, line, entry)
end

--- Assign a final relevance to the entry, given the filter text
---@param prompt string: The filter text
---@param entry table: The entry will be modified in-place
return function(prompt, entry)
  local vn_score = normalize_fzy_score(fzy_score(prompt, entry.virtual_name, entry))
  entry.scores.virtual_name = weights.virtual_name * vn_score

  local path_score = normalize_fzy_score(fzy_score(prompt, entry.path, entry))
  entry.scores.path = weights.path * path_score

  local relevance = entry.scores.virtual_name + entry.scores.path

  entry.relevance = entry.base_score + relevance
  entry.hide = relevance <= 0
end
