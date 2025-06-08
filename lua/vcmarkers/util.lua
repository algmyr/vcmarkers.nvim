M = {}

---@param table table
---@param elements table
function M.extend(table, elements)
  for _, element in ipairs(elements) do
    table[#table + 1] = element
  end
end

return M
