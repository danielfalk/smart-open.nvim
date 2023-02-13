local function priority_insert(insert_into, limit, to_insert, accessor)
  local prev
  local inserted = false

  for i, value in ipairs(insert_into) do
    if prev then
      insert_into[i] = prev
      prev = value
    elseif accessor(to_insert) > accessor(value) then
      insert_into[i] = to_insert
      inserted = true
      prev = value
    end
  end

  if #insert_into < limit then
    table.insert(insert_into, prev or to_insert)
    return true
  end

  return inserted
end

return priority_insert
