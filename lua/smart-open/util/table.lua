local M = {}

function M.shallow_copy(table)
  local t2 = {}

  for k, v in pairs(table) do
    t2[k] = v
  end

  return t2
end

function M.reduce(list, fn, init)
  local acc = init
  for k, v in ipairs(list) do
    if 1 == k and not init then
      acc = v
    else
      acc = fn(acc, v)
    end
  end
  return acc
end

function M.sum(t)
  return M.reduce(t, function(a, b)
    return a + b
  end, 0)
end

function M.max(t)
  return M.reduce(t, function(a, b)
    return (a > b) and a or b
  end, 0)
end

function M.subset(t, first, last)
  local result = {}
  for i = first, last do
    table.insert(result, t[i])
  end
  return result
end

return M
