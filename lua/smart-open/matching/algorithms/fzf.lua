local function normalize_fzf_score(fzf_score, len)
  -- A negative score means no match
  if fzf_score < 0 then
    return 0
  end

  -- Uninvert the score, which puts most scores ~ between 40 and 160
  -- Subtract a small amount for length to give preference to shorter strings
  fzf_score = 1 / fzf_score - 0.001 * len
  -- normalize
  return 1 / (1 + math.exp(-0.035 * fzf_score + 5))
end

local ok, sorter = pcall(function()
  return require("smart-open.matching.algorithms.fzf_implementation")({
    case_mode = "smart_case",
    fuzzy = true,
  })
  -- return extensions.fzf.native_fzf_sorter()
end)

if not ok then
  print(
    "Warning: Couldn't load fzf.  Do you need to add nvim-telescope/telescope-fzf-native.nvim to your dependencies?"
  )
  print("Error loading fzf:", sorter)
  return require("smart-open.matching.algorithms.fzy")
else
  sorter:init()
end

return {
  init = function() end,
  score = function(prompt, line)
    return normalize_fzf_score(sorter:scoring_function(prompt, line), #line)
  end,
  destroy = sorter.destroy,
}
