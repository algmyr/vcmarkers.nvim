local M = {}

function M.get_levels_impl(markers, context, last_line)
  local max_level = #context

  local levels = {}
  for line = 1, last_line do
    levels[line] = max_level
  end

  local function f(margin, value)
    for _, marker in ipairs(markers) do
      local start = marker.start_line + 1
      local count = marker.end_line - marker.start_line
      for i = start - margin, start + count - 1 + margin do
        if i >= 1 and i <= last_line then
          levels[i] = value
        end
      end
    end
  end

  -- Sort in descending order to apply larger margins first.
  table.sort(context, function(a, b)
    return a > b
  end)
  for i, margin in ipairs(context) do
    f(margin, max_level - i)
  end

  return levels
end

local function _get_levels(markers)
  local context = vim.g.vcmarkers_fold_context_sizes
  local last_line = vim.fn.line "$"
  return M.get_levels_impl(markers, context, last_line)
end

---@param lnum integer
function M.fold_expression(lnum)
  local markers = vim.b.vcmarkers_markers
  if markers == nil then
    return 0
  end
  if vim.b.vcmarkers_fold_changedtick ~= vim.b.changedtick then
    vim.b.vcmarkers_fold_changedtick = vim.b.changedtick
    -- Update cached fold levels.
    vim.b.levels = _get_levels(markers)
  end
  return vim.b.levels[lnum] or 0
end

local function _enable()
  local markers = vim.b.vcmarkers_markers
  if markers == nil then
    error "No markers available for folding."
  end
  vim.b.levels = _get_levels(markers)

  vim.wo.foldexpr = 'v:lua.require("vcmarkers.fold").fold_expression(v:lnum)'

  vim.wo.foldmethod = "expr"
  vim.wo.foldlevel = 0
end

local function _disable()
  vim.wo.foldmethod = vim.b.vcmarkers_folded.method
  vim.wo.foldtext = vim.b.vcmarkers_folded.text
  vim.cmd "normal! zv"
end

function M.toggle()
  if vim.b.vcmarkers_folded then
    _disable()
    if vim.b.vcmarkers_folded.method == "manual" then
      vim.cmd "loadview"
    end
    vim.b.vcmarkers_folded = nil
  else
    vim.b.vcmarkers_folded =
      { method = vim.wo.foldmethod, text = vim.wo.foldtext }
    if vim.wo.foldmethod == "manual" then
      local old_vop = vim.o.viewoptions
      vim.cmd "mkview"
      vim.o.viewoptions = old_vop
    end
    _enable()
  end
end

return M
