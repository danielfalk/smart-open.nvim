local function combine_display(display)
  local full = {}
  local hl_group = {}
  local width = 0

  for _, v in ipairs(display) do
    table.insert(full, v[1])

    if v.hl_group then
      -- Increment all offsets to put the highlighting in the right place
      for _, hl in ipairs(v.hl_group) do
        local offset = unpack(hl)
        offset[1] = offset[1] + width
        offset[2] = offset[2] + width

        table.insert(hl_group, hl)
      end
    end

    width = width + #v[1]
  end

  return { table.concat(full, ""), hl_group = hl_group }
end

return combine_display
