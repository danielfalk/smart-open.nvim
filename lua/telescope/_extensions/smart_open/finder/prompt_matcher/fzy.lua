local extensions = require("telescope").extensions
local sorters = require("telescope.sorters")

local function normalize_fzy_score(fzy_score)
  -- A negative score means no match
  if fzy_score < 0 then
    return 0
  end
  return 1 - 1 / (1 + math.exp(-10 * (fzy_score * 10 - 0.65)))
end

local ok, sorter = pcall(function()
  return extensions.fzy_native.native_fzy_sorter()
end)

if not ok then
  sorter = sorters.get_fzy_sorter()
end

-- local prompt_matcher = require("telescope._extensions.smart_open.finder.prompt_matcher.fzf")

return function(prompt, line, entry)
  -- local alternative = prompt_matcher(prompt, line, entry)
  local result = normalize_fzy_score(sorter:scoring_function(prompt, line, entry))
  -- if #prompt > 2 and result < 1 and result > 0.1 then
  --   print(vim.inspect(result), vim.inspect(alternative), line, prompt)
  -- end
  return result
end
