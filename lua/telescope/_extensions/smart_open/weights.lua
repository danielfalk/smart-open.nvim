local shallow_copy = require("smart-open.util.table").shallow_copy

local ADJUSTMENT_POINTS = 0.6 -- Increasing this leads to faster learning, but more drastic behavior swings

local M = {}

M.default_weights = {
  path_fzf = 140,
  path_fzy = 140,
  virtual_name_fzy = 131,
  virtual_name_fzf = 131,
  open = 3,
  alt = 4,
  proximity = 13,
  project = 10,
  frecency = 17,
  recency = 9,
}

--- Select results to learn from that weren't selected
---@param results table: Finder results, sorted in order of score
---@param selected_path string: Path that the user selected
local function select_misses(results, selected_path)
  local found_selected = false
  local max_misses = 15
  local target_misses = 1
  local greater_results = {}
  local lesser_results = {}

  for _, v in ipairs(results) do
    local count = #greater_results + #lesser_results

    if selected_path == v.path then
      found_selected = true
    elseif not found_selected then
      -- Weight all items that ranked higher than what was selected
      table.insert(greater_results, v)
      if count >= max_misses then
        break
      end
    else
      if count >= target_misses then
        break
      end

      table.insert(lesser_results, v)
    end
  end

  return greater_results, lesser_results
end

-- Adjust weights based on the various scores
local function adjust_weights(original_weights, weights, success_entry, miss_entry, factor)
  -- skip any adjustment if the user is just going back to current
  if success_entry.current or miss_entry.current then
    return
  end

  -- Un-apply the original weight to get the raw score
  local function get_unweighted(key, original_weight, entry)
    return entry.scores[key] and entry.scores[key] / original_weight
  end

  local to_deduct = 0
  local to_add = 0

  -- Total up the amounts to add and deduct
  for k, v in pairs(original_weights) do
    local hit_weight = get_unweighted(k, v, success_entry)
    local miss_weight = get_unweighted(k, v, miss_entry)

    if miss_weight ~= nil and hit_weight ~= nil then
      if miss_weight > hit_weight then
        to_deduct = to_deduct + (miss_weight - hit_weight)
      elseif hit_weight > miss_weight then
        to_add = to_add + (hit_weight - miss_weight)
      end
    end
  end

  -- Deduct from the weights where the miss scored higher than the hit.
  -- Add to the weights where the hit scored higher than the miss.
  -- Deduct/add proportionately such that the biggest differences in weight between the
  -- hit and miss get more addition/deduction
  for k, v in pairs(original_weights) do
    local hit_weight = get_unweighted(k, v, success_entry)
    local miss_weight = get_unweighted(k, v, miss_entry)

    if miss_weight ~= nil and hit_weight ~= nil then
      local new_result = weights[k]

      if miss_weight > hit_weight then
        new_result = math.max(1, weights[k] - ADJUSTMENT_POINTS * factor * ((miss_weight - hit_weight) / to_deduct))
      elseif hit_weight > miss_weight then
        new_result = weights[k] + ADJUSTMENT_POINTS * factor * ((hit_weight - miss_weight) / to_add)
      end

      weights[k] = new_result
    end
  end
end

--- "Learns" from what was selected and adjusts weights
--- in response
---@param original_weights table: Original weights
---@param results table: Finder results, sorted in order of score
---@param selected table: Entry that the user selected
---@returns weights revised weights
function M.revise_weights(original_weights, results, selected)
  local new_weights = shallow_copy(original_weights)
  local greater_misses, lesser_misses = select_misses(results, selected.path)

  if #greater_misses + #lesser_misses == 0 then
    return original_weights
  end

  -- Add and subtract amounts to the weights that contributed to the score.
  -- The weights should be boosted according to the proportion that the category contributed
  -- to the final score
  for _, miss in pairs(greater_misses) do
    adjust_weights(original_weights, new_weights, selected, miss, 1 / #greater_misses)
  end
  for _, miss in pairs(lesser_misses) do
    adjust_weights(original_weights, new_weights, selected, miss, 0.1 / #lesser_misses)
  end

  return new_weights
end

return M
