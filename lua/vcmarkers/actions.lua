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
  vim.b[bufnr].vcmarkers_disabled = false
  local need_attach = not vim.b[bufnr].vcmarkers_highlight_enabled
  if need_attach then
    local function cb(event, buffer)
      -- The different callbacks take different arguments,
      -- but the buffer is always there.
      --
      -- Make this more granular? Would make the namespace stuff more annoying.
      -- Could clear highlights just in the region rather than nuke whole namespace.
      _update_markers(buffer)
      return _handle_update(buffer)
    end

    vim.b[bufnr].vcmarkers_highlight_enabled = true
    vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = cb,
      on_changedtick = cb,
      on_reload = cb,
    })
    -- Disable diagnostics for this buffer.
    -- Conflict markers tend to not play well with linters and the like.
    vim.b[bufnr].vcmarkers_enabled = vim.diagnostic.is_enabled { bufnr = bufnr }
    vim.diagnostic.enable(false, { bufnr = bufnr })
  end

  -- Update immediately.
  _update_markers(bufnr)
  highlight.redraw_highlight(bufnr, vim.b[bufnr].vcmarkers_markers)
end

function M.start_if_markers(bufnr)
  _update_markers(bufnr)
  if vim.b[bufnr].vcmarkers_markers and #vim.b[bufnr].vcmarkers_markers > 0 then
    M.start(bufnr)
  end
end

--- Stop highlighting diff markers.
---@param bufnr number Buffer number.
function M.stop(bufnr)
  vim.b[bufnr].vcmarkers_disabled = true
  vim.b[bufnr].vcmarkers_highlight_enabled = false
  highlight.clear_highlights(bufnr)
  -- Re-enable diagnostics if they were enabled before.
  if vim.b[bufnr].vcmarkers_enabled then
    vim.diagnostic.enable(true, { bufnr = bufnr })
  end
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

---@param bufnr integer The buffer number.
function M.select_section(bufnr)
  local lnum = vim.fn.line "."
  local diff_markers = vim.b[bufnr].vcmarkers_markers
  local marker = markers.cur_marker(lnum, diff_markers)
  if not marker then
    vim.notify(
      "No marker under cursor",
      vim.log.levels.WARN,
      { title = "VCMarkers" }
    )
    return
  end

  local section = markers.current_section(marker, lnum)
  if not section then
    vim.notify(
      "No section under cursor",
      vim.log.levels.WARN,
      { title = "VCMarkers" }
    )
    return
  end

  -- Could check that the section is actually a "plus" section,
  -- but let's trust the user for now.
  vim.api.nvim_buf_set_lines(
    bufnr,
    marker.start_line,
    marker.end_line,
    true,
    section.lines
  )
  vim.api.nvim_win_set_cursor(0, { marker.start_line + 1, 0 })
end

--- Convert markers to a different format.
function M.cycle_marker(bufnr)
  local lnum = vim.fn.line "."
  local diff_markers = vim.b[bufnr].vcmarkers_markers
  local marker = markers.cur_marker(lnum, diff_markers)

  if not marker then
    vim.notify(
      "No marker under cursor",
      vim.log.levels.WARN,
      { title = "VCMarkers" }
    )
    return
  end

  local updated_marker = markers.cycle_marker(marker)
  marker.end_label = updated_marker.end_label
  marker.end_line = updated_marker.end_line
  marker.label = updated_marker.label
  marker.prefix_len = updated_marker.prefix_len
  marker.sections = updated_marker.sections
  marker.start_line = updated_marker.start_line

  vim.api.nvim_buf_set_lines(
    bufnr,
    marker.start_line,
    marker.end_line,
    true,
    markers.materialize_marker(marker)
  )
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
end

return M
