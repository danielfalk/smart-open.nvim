local fzy

local function normalize_fzy_score(fzy_score)
  -- A negative score means no match
  if fzy_score < 0 then
    return 0
  end
  return 1 - 1 / (1 + math.exp(-10 * (fzy_score * 10 - 0.65)))
end

local function score(prompt, line)
  -- Check for actual matches before running the scoring alogrithm.
  if not fzy.has_match(prompt, line) then
    return -1
  end

  local fzy_score = fzy.score(prompt, line)

  -- The fzy score is -inf for empty queries and overlong strings.  Since
  -- this function converts all scores into the range (0, 1), we can
  -- convert these to 1 as a suitable "worst score" value.
  if fzy_score == fzy.get_score_min() then
    return 1
  end

  -- Poor non-empty matches can also have negative values. Offset the score
  -- so that all values are positive, then invert to match the
  -- telescope.Sorter "smaller is better" convention. Note that for exact
  -- matches, fzy returns +inf, which when inverted becomes 0.
  return 1 / (fzy_score - fzy.get_score_floor())
end

return {
  init = function(options)
    if options.native_fzy_path then
      fzy = loadfile(options.native_fzy_path)()
    else
      fzy = require("smart-open.matching.algorithms.fzy_implementation")
    end
  end,
  score = function(prompt, line)
    local result = normalize_fzy_score(score(prompt, line))
    return result
  end,
  destroy = function() end,
}
