-- prompt, cancel_token, options, last_processed_index
local function process(prompt, cancel_token, encoded_options, encoded_entries)
  local result_limit = 20

  local ok, result = pcall(function()
    local options = vim.mpack.decode(encoded_options)
    local entries = vim.mpack.decode(encoded_entries)
    assert(options)
    assert(entries)

    result_limit = options.result_limit or result_limit

    local results = {}

    local set_relevance = require("telescope._extensions.smart_open.finder.set_relevance")(options)
    local priority_insert = require("smart-open.util.priority_insert")

    for _, entry in ipairs(entries) do
      local path, base_score, vname_pos = unpack(entry)

      local e = { path = path, virtual_name = path:sub(vname_pos), base_score = base_score }
      if prompt and #prompt > 0 then
        set_relevance.run(prompt, e)
      else
        e.relevance = e.base_score
      end

      if not e.hide then
        priority_insert(results, result_limit, e, function(o)
          return o.relevance
        end)
      end
    end

    set_relevance.destroy()

    return results, cancel_token
  end)

  local packed = vim.mpack.encode({ status = ok, result = result, cancel_token = cancel_token })

  return packed
end

return process
