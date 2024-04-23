local file_scanner = require("telescope._extensions.smart_open.file_scanner")
local create_entry_data = require("smart-open.entry.create")
local create_multithread_matcher = require("smart-open.matching.multithread.create")
local priority_insert = require("smart-open.util.priority_insert")
local virtual_name = require("smart-open.util.virtual_name")

--- Creates a finder that combines entries from our smart_open db and
--- output from ripgrep
---@param history object: History instance
---@param opts table: Finder options...
--- * display function
--- * cwd string
--- * cwd_only boolean If true, only returns results under cwd
--- * ignore_patterns table
--- * match_algorithm string 'fzy' (default) or 'fzf'
--- * result_limit number
return function(history, opts, context)
  local results = {}
  local db_results = {}
  local is_added = {}

  local history_result, max_score = history:get_all(opts.cwd_only and opts.cwd)

  local match_runner = create_multithread_matcher({
    match_algorithm = opts.match_algorithm,
    result_limit = opts.result_limit,
  }, context)

  for _, v in ipairs(history_result) do
    if v.exists then
      local history_data = {
        frecency = v.score / max_score,
        recent_rank = v.recent_rank,
      }
      local entry_data = create_entry_data(v.path, history_data, context)
      entry_data.virtual_name = virtual_name.get_virtual_name(v.path)

      -- for deduplication
      is_added[v.path] = true

      table.insert(db_results, entry_data)
      match_runner.add_entry(entry_data, history_data)
    end
  end

  local h = { frecency = 0, recent_rank = 0 }

  file_scanner(opts.cwd, opts.ignore_patterns, function(fullpath)
    if not is_added[fullpath] then
      local entry_data = create_entry_data(fullpath, h, context)
      match_runner.add_entry(entry_data)
    end
  end, function()
    match_runner.entries_complete()
  end)

  return setmetatable({
    close = function() end,
    get_status_text = function()
      return tostring(#is_added)
    end,
  }, {
    __index = function(t, k)
      if k == "results" then
        return results
      end
      return rawget(t, k)
    end,
    __call = function(_, prompt, process_result, process_complete)
      results = {}

      local result_limit = opts.result_limit or 50

      if prompt == "" and #db_results >= result_limit then
        for _, result in pairs(db_results) do
          priority_insert(results, result_limit, result, function(x)
            return x.base_score
          end)
        end

        for _, v in ipairs(results) do
          local to_insert = vim.tbl_extend(
            "keep",
            { ordinal = v.base_score, display = opts.display, prompt = prompt },
            v
          )
          if process_result(to_insert) then
            break
          end
        end

        process_complete()
        match_runner.cancel()
      end

      match_runner.init(
        prompt,
        vim.schedule_wrap(function(entry)
          local to_insert = vim.tbl_extend(
            "keep",
            { ordinal = entry.relevance, display = opts.display, prompt = prompt },
            entry
          )

          priority_insert(results, result_limit, to_insert, function(e)
            return e.relevance or e.base_score
          end)

          return process_result(to_insert)
        end),
        process_complete
      )
    end,
  })
end
