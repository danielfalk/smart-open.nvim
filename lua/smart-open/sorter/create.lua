local sorters = require("telescope.sorters")
local get_fzf_sorter = require("smart-open.matching.algorithms.fzf_implementation")

local function create_sorter(matching_algorithm)
  local fzf_sorter = get_fzf_sorter({
    case_mode = "smart_case",
    fuzzy = true,
  })
  return sorters.Sorter:new({
    -- Just reverse the relevance values for sorting
    scoring_function = function(_, _, x)
      return -x
    end,

    highlighter = fzf_sorter.highlighter,
    -- highlighter = sorters.get_fzy_sorter().highlighter
    -- highlighter = function(self, prompt, display)
    --   -- if self.__highlight_prefilter then
    --   --   prompt = self:__highlight_prefilter(prompt)
    --   -- end
    --   return fzf.get_pos(display, get_struct(self, prompt), self.state.slab)
    -- end,
    -- highlighter = function(_, prompt, display)
    --   return fzy.positions(prompt, display)
    -- end,
  })
end

return create_sorter
