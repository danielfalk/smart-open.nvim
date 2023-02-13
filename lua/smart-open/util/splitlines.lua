local function splitlines(str)
  local pos = 0

  return function()
    if pos == #str then
      return nil
    end

    local result
    local found = str:find("[\r\n]", pos + 1)

    if found then
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

return splitlines
