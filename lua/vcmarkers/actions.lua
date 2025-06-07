local M = {}

local markers = require "vcmarkers.markers"
local highlight = require "vcmarkers.highlight"

---@param bufnr number Buffer number.
local function _update_markers(bufnr)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local diff_markers = markers.extract_diff_markers(all_lines)
  vim.b[bufnr].vcmarkers_markers = diff_markers
end

---@param bufnr number Buffer number.
local function _handle_update(bufnr)
  local diff_markers = vim.b[bufnr].vcmarkers_markers

  if #diff_markers == 0 then
    vim.b[bufnr].vcmarkers_highlight_enabled = false
  end

  if vim.b[bufnr].vcmarkers_highlight_enabled then
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
  local need_attach = not vim.b[bufnr].vcmarkers_highlight_enabled
  if need_attach then
    vim.b[bufnr].vcmarkers_highlight_enabled = true
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
  highlight.redraw_highlight(bufnr, vim.b[bufnr].vcmarkers_markers)
end

--- Stop highlighting diff markers.
---@param bufnr number Buffer number.
function M.stop(bufnr)
  vim.b[bufnr].vcmarkers_highlight_enabled = false
  highlight.clear_highlights(bufnr)
end

---@param bufnr integer The buffer number.
---@param count integer The number of markers ahead.
function M.next_marker(bufnr, count)
  if vim.o.diff then
    vim.cmd "normal! ]c"
    return
  end
  local lnum = vim.fn.line "."
  local diff_markers = vim.b[bufnr].vcmarkers_markers
  local marker = markers.next_marker(lnum, diff_markers, count)
  if marker then
    vim.cmd "normal! m`"
    vim.api.nvim_win_set_cursor(0, { marker.start_line + 1, 0 })
  end
end

---@param bufnr integer The buffer number.
---@param count integer The number of markers ahead.
function M.prev_marker(bufnr, count)
  if vim.o.diff then
    vim.cmd "normal! [c"
    return
  end
  local lnum = vim.fn.line "."
  local diff_markers = vim.b[bufnr].vcmarkers_markers
  local marker = markers.prev_marker(lnum, diff_markers, count)
  if marker then
    vim.cmd "normal! m`"
    vim.api.nvim_win_set_cursor(0, { marker.start_line + 1, 0 })
  end
end

return M
