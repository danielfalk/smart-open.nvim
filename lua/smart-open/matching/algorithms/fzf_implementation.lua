local fzf = require("fzf_lib")

local case_enum = setmetatable({
  ["smart_case"] = 0,
  ["ignore_case"] = 1,
  ["respect_case"] = 2,
}, {
  __index = function(_, k)
    error(string.format("%s is not a valid case mode", k))
  end,
  __newindex = function()
    error("Don't set new things")
  end,
})

local get_fzf_sorter = function(opts)
  local case_mode = case_enum[opts.case_mode]
  local fuzzy_mode = opts.fuzzy == nil and true or opts.fuzzy

  local state = {
    prompt_cache = {}
  }

  local get_struct = function(prompt)
    local struct = state.prompt_cache[prompt]
    if not struct then
      struct = fzf.parse_pattern(prompt, case_mode, fuzzy_mode)
      state.prompt_cache[prompt] = struct
    end
    return struct
  end

  local M = {}

  function M.init()
    state.slab = fzf.allocate_slab()
    state.prompt_cache = {}
  end

  function M.scoring_function(_, prompt, line)
    local obj = get_struct(prompt)
    local score = fzf.get_score(line, obj, state.slab)
    if score == 0 then
      return -1
    else
      return 1 / score
    end
  end

  function M.highlighter(_, prompt, display)
      return fzf.get_pos(display, get_struct(prompt), state.slab)
  end

  function M.destroy()
    for _, v in pairs(state.prompt_cache) do
      fzf.free_pattern(v)
    end
    state.prompt_cache = {}
    if state.slab ~= nil then
      fzf.free_slab(state.slab)
      state.slab = nil
    end
  end

  return M
end

return get_fzf_sorter
