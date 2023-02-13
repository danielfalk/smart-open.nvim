local uv = vim.loop

local util = {}

-- stolen from penlight

-- escape any Lua 'magic' characters in a string
util.escape = function(str)
  return (str:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1"))
end

util.filemask = function(mask)
  mask = util.escape(mask)
  return "^" .. mask:gsub("%%%*", ".*"):gsub("%%%?", ".") .. "$"
end

util.filename_match = function(filename, pattern)
  return filename:find(util.filemask(pattern)) ~= nil
end

util.string_isempty = function(str)
  return str == nil or str == ""
end

util.split = function(str, delimiter)
  local result = {}
  for match in str:gmatch("[^" .. delimiter .. "]+") do
    table.insert(result, match)
  end
  return result
end

util.fs_stat = function(path)
  local stat = uv.fs_stat(path)
  local res = {}
  res.exists = stat and true or false -- TODO: this is silly
  res.isdirectory = (stat and stat.type == "directory") and true or false

  return res
end

function util.shift_hl(hl_group, offset)
  local positions = hl_group[1]
  if positions then
    positions[1] = positions[1] + offset
    positions[2] = positions[2] + offset
  end
  return hl_group
end

-- This is slow, and only useful temporarily in debugging situations as a replacement for vim.mpack.encode
function util.pack(obj, path)
  if type(obj) == "table" then
    for k, v in pairs(obj) do
      local ok, result = util.pack(v, path and (path .. "." .. k) or k)
      if not ok then
        return ok, result
      end
    end
  end

  local ok, result = pcall(vim.mpack.encode, obj)

  if not ok then
    return false, "Path " .. path .. " could not be packed"
  else
    return ok, result
  end
end

return util
