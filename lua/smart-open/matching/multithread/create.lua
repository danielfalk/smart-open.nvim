local priority_insert = require("smart-open.util.priority_insert")
local process = require("smart-open.matching.multithread.process")
local create_entry_data = require("smart-open.entry.create")
local virtual_name = require("smart-open.util.virtual_name")

---@param opts table: matcher options...
--- * match_algorithm string
--- * result_limit number
---@param context table: context options
local function create_matcher(opts, context)
  local matching_algorithm = opts.match_algorithm
  local cancel_token = 0
  local complete = false
  local prompt = nil
  local process_result
  local process_complete
  local slot_count = 4 -- threadpool thread count
  local last_processed_index = 0
  local top_entries = {} -- treat it as ascending (lowest relevance last)
  local top_entry_count = opts.result_limit or 40
  local waiting_threads = 0
  local history_data_cache = {}

  local unpacked = {}
  local packed = {}

  local M = {}

  local native_fzy_path = matching_algorithm ~= "fzf"
    and vim.api.nvim_get_runtime_file("deps/fzy-lua-native/lua/native.lua", false)[1]

  local opt_table = {
    matching_algorithm = matching_algorithm,
    native_fzy_path = native_fzy_path or nil,
    weights = context.weights,
  }

  if opts.result_limit then
    opt_table.result_limit = opts.result_limit
  end

  local options = vim.mpack.encode(opt_table)

  local function combine_with_main(thread_top_entries)
    for _, entry in ipairs(thread_top_entries) do
      local inserted = priority_insert(top_entries, top_entry_count, entry, function(o)
        return o.relevance or o.base_score
      end)

      if not inserted then
        break
      end

      local entry_to_add = create_entry_data(
        entry.path,
        history_data_cache[entry.path] or { frecency = 0, recent_rank = 0 },
        context
      )

      process_result(vim.tbl_deep_extend("keep", entry_to_add, entry))
    end
  end

  function M.process()
    if #unpacked > 0 then
      table.insert(packed, vim.mpack.encode(unpacked))
      unpacked = {}
    end

    if not process_result then
      return
    end

    local pool

    local function queue_next()
      if last_processed_index >= #packed then
        return false
      end

      waiting_threads = waiting_threads + 1

      last_processed_index = last_processed_index + 1

      vim.loop.queue_work(pool, prompt, cancel_token, options, packed[last_processed_index])
    end

    -- Divide the work and send to queues
    pool = vim.loop.new_work(process, function(encoded)
      waiting_threads = waiting_threads - 1

      local work_result = vim.mpack.decode(encoded)
      assert(work_result)

      if not work_result.status then
        print("Work result error:", work_result.result, work_result.stack)
        return
      end

      if work_result.cancel_token == cancel_token then
        -- This particular search hasn't been canceled, so yield these results and queue more work
        queue_next()

        combine_with_main(work_result.result)

        if complete and waiting_threads == 0 and last_processed_index == #packed then
          process_complete()
        end
      end
    end)

    for _ = 1, slot_count do
      if not queue_next() then
        break
      end
    end
  end

  function M.cancel()
    cancel_token = cancel_token + 1
    last_processed_index = 0
    top_entries = {}
  end

  function M.add_entry(entry, history_data)
    table.insert(unpacked, { entry.path, entry.base_score, virtual_name.get_pos(entry.path) })

    if history_data then
      history_data_cache[entry.path] = history_data
    end

    if #unpacked > 15000 then
      M.process()
    end
  end

  function M.entries_complete()
    complete = true
    M.process()
  end

  function M.init(p, proc, proc_complete)
    if p ~= prompt then
      M.cancel()
    end

    prompt = p
    process_result = proc
    process_complete = proc_complete

    if #unpacked == 0 or #unpacked > 500 then
      M.process()
    end
  end

  return M
end

return create_matcher
