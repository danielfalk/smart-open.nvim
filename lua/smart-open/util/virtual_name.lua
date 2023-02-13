local is_index_filename = {
  ["index.js"] = true,
  ["index.ts"] = true,
  ["index.jsx"] = true,
  ["index.tsx"] = true,
  ["index.test.js"] = true,
  ["index.test.ts"] = true,
  ["index.test.jsx"] = true,
  ["index.test.tsx"] = true,
  ["__init__.py"] = true,
  ["init.lua"] = true,
}

local M = {}

function M.get_pos(path)
  local last, penultimate, current
  local k = 0
  repeat
    penultimate = last
    last = current
    current, k = path:find("/", k + 1, true)
  until current == nil

  return is_index_filename[path:sub(last + 1, path:len())] and penultimate + 1 or last + 1
end

function M.get_virtual_name(path)
  return path:sub(M.get_pos(path))
end

return M
