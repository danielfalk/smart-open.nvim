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
  ["default.nix"] = true,
  ["package.d"] = true,
}

local M = {}

local win32 = vim.fn.has("win32") == 1
local path_separator = package.config:sub(1, 1)

function M.get_pos(path)
  local last, penultimate, current
  local k = 0

  -- enforce consistent path separator on windows to account for both forward and backward slashes
  if win32 then
    path = path:gsub("/", path_separator):gsub("\\", path_separator)
  end

  repeat
    penultimate = last
    last = current
    local path_separator = package.config:sub(1, 1)
    current, k = path:find(path_separator, k + 1, true)
  until current == nil

  if not last then
    -- no path separator found, so return the start of the string (a.k.a. use the whole string)
    return 1
  end

  local filename = path:sub(last + 1)

  if is_index_filename[filename] and penultimate then
    return penultimate + 1
  else
    return last + 1
  end
end

function M.get_virtual_name(path)
  return path:sub(M.get_pos(path))
end

return M
