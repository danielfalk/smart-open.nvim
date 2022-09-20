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

--

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

function util.table_shallow_copy(t)
  local t2 = {}

  for k, v in pairs(t) do
    t2[k] = v
  end

  return t2
end

function util.splitlines(str)
  local pos = 0

  return function()
    if pos == #str then
      return nil
    end

    local result
    local found = str:find("[\r\n]", pos + 1)
    if found ~= nil then
      result = str:sub(pos, found - 1)

      if str:sub(found, found + 1) == "\r\n" then
        pos = found + 2
      else
        pos = found + 1
      end

      return result, true
    else
      result = str:sub(pos, #str)
      pos = #str
      return result, false
    end
  end
end


return util
