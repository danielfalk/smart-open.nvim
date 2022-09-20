return function()
  local result = {}

  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(buf) == 1 and vim.api.nvim_buf_is_loaded(buf) then
      result[vim.api.nvim_buf_get_name(buf)] = true
    end
  end

  return result
end
