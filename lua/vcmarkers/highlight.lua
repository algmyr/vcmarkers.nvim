local M = {}

local markers = require "vcmarkers.markers"

local base_prio = 200

local function _highlight_marker(bufnr, ns, marker)
  local function highlight_span(group, line_nr, l, r)
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr, l, {
      end_col = r,
      hl_group = group,
      priority = base_prio + 1,
      hl_mode = "combine",
    })
  end

  local function highlight_line(group, line_nr, end_line_nr)
    -- Workaround from https://github.com/lewis6991/gitsigns.nvim/issues/1115#issuecomment-2319497559
    end_line_nr = end_line_nr or line_nr + 1
    vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr, 0, {
      end_line = end_line_nr,
      hl_group = group,
      priority = base_prio,
      end_col = 0,
      hl_eol = true,
      strict = false,
    })
  end

  highlight_line("VCMarkersMarker", marker.start_line)
  for _, section in ipairs(marker.sections) do
    if markers.is_minus(section) then
      local end_line = section.content_line + #section.lines
      highlight_line("DiffDelete", section.content_line, end_line)
    elseif markers.is_plus(section) then
      local end_line = section.content_line + #section.lines
      highlight_line("DiffAdd", section.content_line, end_line)
    elseif markers.is_diff(section) then
      for i, line in ipairs(section.lines) do
        local line_nr = section.content_line + i - 1
        local c = line:sub(1, 1)
        if c == "-" then
          highlight_span("DiffDelete", line_nr, 0, #line)
        elseif c == "+" then
          highlight_span("DiffAdd", line_nr, 0, #line)
        end
      end
    else
      error("Unknown section kind: " .. vim.inspect(section.kind))
    end

    if section.header_line then
      highlight_line(
        "VCMarkersSectionHeader",
        section.header_line,
        section.content_line
      )
    end
  end
  highlight_line("VCMarkersMarker", marker.end_line - 1, marker.end_line)
end

local function _namespace()
  return vim.api.nvim_create_namespace "vcmarkers"
end

function M.clear_highlights(bufnr)
  local ns = _namespace()
  vim.api.nvim_buf_clear_namespace(bufnr or 0, ns, 0, -1)
end

function M.redraw_highlight(bufnr, diff_markers)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  M.clear_highlights(bufnr)
  local ns = _namespace()
  for _, marker in ipairs(diff_markers) do
    _highlight_marker(bufnr, ns, marker)
  end
end

return M
