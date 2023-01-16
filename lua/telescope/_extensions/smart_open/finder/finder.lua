local file_scanner = require("telescope._extensions.smart_open.file_scanner")
local configure_set_relevance = require("telescope._extensions.smart_open.finder.set_relevance")

--- Creates a finder that combines entries from our smart_open db and
--- output from ripgrep
---@param history object: History instance
---@param opts table: Finder options...
--- * entry_maker function
--- * cwd string
--- * cwd_only boolean If true, only returns results under cwd
--- * ignore_patterns table
--- * max_unindexed number
--- * match_algorithm string 'fzy' (default) or 'fzf'
return function(history, opts)
  local results = {}
  local is_added = {}
  local unindexed_count = 0
  local set_relevance = configure_set_relevance(opts.match_algorithm)

  local history_result, max_score = history:get_all(opts.cwd_only and opts.cwd)

  for i, v in ipairs(history_result) do
    local entry = opts.entry_maker(v, max_score)
    if entry and v.exists then
      -- for deduplication
      is_added[v.path] = true
      entry.index = i
      table.insert(results, entry)
    end
  end

  local total = #results

  file_scanner(opts.cwd, opts.ignore_patterns, function(fullpath)
    if not is_added[fullpath] then
      local entry = opts.entry_maker({ path = fullpath, score = 1, exists = true }, max_score)
      if not entry then
        return
      end
      entry.index = total + unindexed_count
      table.insert(results, entry)

      unindexed_count = unindexed_count + 1
      if unindexed_count > opts.max_unindexed then
        return false
      end
    end
  end, function() end)

  return setmetatable({
    results = results,
    close = function() end,
    get_status_text = function()
      return tostring(#results)
    end,
  }, {
    __call = function(_, prompt, process_result, process_complete)
      if prompt == "" then
        table.sort(results, function(a, b)
          return a.base_score > b.base_score
        end)
      else
        for _, entry in pairs(results) do
          set_relevance(prompt, entry)
        end

        table.sort(results, function(a, b)
          return a.relevance > b.relevance
        end)
      end

      local added_count = 0

      for _, v in ipairs(results) do
        if prompt == "" or not v.hide then
          v.ordinal = added_count
          added_count = added_count + 1

          if process_result(v) or added_count == 50 then
            break
          end
        end
      end

      process_complete()
    end,
  })
end
