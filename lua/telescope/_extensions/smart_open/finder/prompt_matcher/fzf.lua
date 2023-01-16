local extensions = require("telescope").extensions

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
  return extensions.fzf.native_fzf_sorter()
end)

if not ok then
  print("Warning: Couldn't load fzf.  Falling back to fzy")
  return require("telescope._extensions.smart_open.finder.prompt_matcher.fzy")
else
  sorter:init()
end

return function(prompt, line, entry)
  return normalize_fzf_score(sorter:scoring_function(prompt, line, entry), #line)
end
