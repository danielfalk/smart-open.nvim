local weights = require("telescope._extensions.smart_open.weights").default_weights


--- Configure set_relevance function with a matching_algorithm
---@param matching_algorithm string: fzf or fzy
return function(matching_algorithm)
  matching_algorithm = matching_algorithm or "fzy"
  assert(matching_algorithm == "fzy" or matching_algorithm == "fzf", "Matching algorigthm must be fzf or fzy")

  local prompt_matcher = require("telescope._extensions.smart_open.finder.prompt_matcher." .. matching_algorithm)

  local update_match_scores = function(prompt, entry)
    local vn_prop = "virtual_name_" .. matching_algorithm
    local vn_score = prompt_matcher(prompt, entry.virtual_name, entry)
    entry.scores[vn_prop] = weights[vn_prop] * vn_score

    local path_prop = "path_" .. matching_algorithm
    local path_score = prompt_matcher(prompt, entry.path, entry)
    entry.scores[path_prop] = weights[path_prop] * path_score

    return entry.scores[vn_prop] + entry.scores[path_prop]
  end

  --- Assign a final relevance to the entry, given the filter text
  --- additionally, store the prompt-match scores on each entry so weights can be recalculated
  ---@param prompt string: The filter text
  ---@param entry table: The entry will be modified in-place
  return function(prompt, entry)
    local match_score = update_match_scores(prompt, entry)

    entry.relevance = entry.base_score + match_score
    entry.hide = match_score <= 0
  end
end
