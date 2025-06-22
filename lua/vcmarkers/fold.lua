local M = {}

local fold = require "vclib.fold"
local interval_lib = require "vclib.intervals"
local markers_lib = require "vcmarkers.markers"

---@param lnum integer
function M.fold_expression(lnum)
  local markers = vim.b.vcmarkers_markers
  if markers == nil then
    return 0
  end
  local intervals = interval_lib.from_list(markers, markers_lib.to_interval)
  fold.maybe_update_levels(intervals, vim.g.vcsigns_fold_context_sizes)
  return vim.b.levels[lnum] or 0
end

local foldexpr = 'v:lua.require("vcmarkers.fold").fold_expression(v:lnum)'

function M.toggle(bufnr)
  fold.toggle(bufnr, foldexpr)
end

return M
