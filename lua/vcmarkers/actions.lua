local M = {}

local markers = require "jjmarkers.markers"
local highlight = require "jjmarkers.highlight"

---@param bufnr number Buffer number.
local function _update_markers(bufnr)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diff_markers = markers.extract_diff_markers(all_lines)
  vim.b[bufnr].jjmarkers_markers = diff_markers
end

---@param bufnr number Buffer number.
local function _handle_update(bufnr)
  local diff_markers = vim.b[bufnr].jjmarkers_markers

  if #diff_markers == 0 then
    vim.b[bufnr].jjmarkers_highlight_enabled = false
  end

  if vim.b[bufnr].jjmarkers_highlight_enabled then
    -- Do not detach.
    highlight.redraw_highlight(bufnr, diff_markers)
    return false
  else
    -- Detach so we don't get called again.
    highlight.clear_highlights(bufnr)
    return true
  end
end

--- Start highlighting diff markers until stopped or none are left.
---@param bufnr number Buffer number.
function M.start(bufnr)
  local need_attach = not vim.b[bufnr].jjmarkers_highlight_enabled
  if need_attach then
    vim.b[bufnr].jjmarkers_highlight_enabled = true
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(
        lines,
        buffer,
        changedtick,
        firstline,
        lastline,
        new_lastline,
        bytecount,
        deleted_codepoints,
        deleted_codeunits
      )
        -- Make this more granular? Would make the namespace stuff more annoying.
        -- Could clear highlights just in the region rather than nuke whole namespace.
        _update_markers(buffer)
        return _handle_update(buffer)
      end,
    })
  end

  -- Update immediately.
  _update_markers(bufnr)
  highlight.redraw_highlight(bufnr, vim.b[bufnr].jjmarkers_markers)
end

--- Stop highlighting diff markers.
---@param bufnr number Buffer number.
function M.stop(bufnr)
  vim.b[bufnr].jjmarkers_highlight_enabled = false
  highlight.clear_highlights(bufnr)
end

return M
