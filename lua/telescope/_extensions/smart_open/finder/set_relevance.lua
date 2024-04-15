--- Configure set_relevance function with a matching_algorithm
---@param options table
--   matching_algorithm string: fzf or fzy
--   native_fzy_path string: the path to the native fzy (only applicable if fzy is selected)
--   weights table: the current weight values
return function(options)
  local matching_algorithm = options.matching_algorithm
  local weights = options.weights

  matching_algorithm = matching_algorithm or "fzy"
  assert(matching_algorithm == "fzy" or matching_algorithm == "fzf", "Matching algorithm must be fzf or fzy")

  local prompt_matcher = require("smart-open.matching.algorithms." .. matching_algorithm)
  prompt_matcher.init(options)

  local update_match_scores = function(prompt, entry)
    local path_prop = "path_" .. matching_algorithm

    local path_score = prompt_matcher.score(prompt, entry.path, entry)
    if path_score == 0 then
      return 0
    end
    entry.scores = entry.scores or {}
    entry.scores[path_prop] = weights[path_prop] * path_score

    local vn_prop = "virtual_name_" .. matching_algorithm
    local vn_score = prompt_matcher.score(prompt, entry.virtual_name, entry)
    entry.scores[vn_prop] = weights[vn_prop] * vn_score

    return entry.scores[vn_prop] + entry.scores[path_prop]
  end

  local M = {}

  --- Assign a final relevance to the entry, given the filter text
  --- additionally, store the prompt-match scores on each entry so weights can be recalculated
  ---@param prompt string: The filter text
  ---@param entry table: The entry will be modified in-place
  function M.run(prompt, entry)
    local match_score = update_match_scores(prompt, entry)

    entry.relevance = entry.base_score + match_score
    entry.ordinal = entry.relevance
    entry.hide = match_score <= 0
  end

  function M.destroy()
    if prompt_matcher.destroy then
      prompt_matcher.destroy()
    end
  end

  return M
end
