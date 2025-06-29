local M = {}

local diff_kinds = require "vcmarkers.diff_kinds"
local intervals = require "vclib.intervals"
local marker_format = require "vcmarkers.marker_format"

local DiffKind = diff_kinds.DiffKind

---@class Section
---@field label string|nil
---@field kind string|nil
---@field header_line integer|nil
---@field content_line integer
---@field lines string[]

---@class Marker
---@field start_line integer
---@field end_line integer
---@field label string
---@field end_label string
---@field prefix_len integer
---@field sections Section[]

---@param marker Marker
---@param lnum integer
---@return Section|nil
function M.current_section(marker, lnum)
  lnum = lnum - 1 -- Convert to zero-based line number.
  for _, section in ipairs(marker.sections) do
    local start = section.header_line or section.content_line
    if start <= lnum and lnum < section.content_line + #section.lines then
      return section
    end
  end
  return nil
end

---@param section Section
function M.is_diff(section)
  return section.kind == DiffKind.DIFF
end

---@param section Section
function M.is_plus(section)
  return (
    section.kind == DiffKind.ADDED
    or section.kind == DiffKind.DIFF3_LEFT
    or section.kind == DiffKind.DIFF3_RIGHT
  )
end

---@param section Section
function M.is_minus(section)
  return section.kind == DiffKind.DELETED or section.kind == DiffKind.DIFF3_BASE
end

local function _pattern(marker, kind)
  return "^(" .. string.rep(kind, marker.prefix_len) .. ") ?(.*)"
end

---@param marker Marker
---@param lines string[]
---@return Section[]
local function _extract_sections(marker, lines)
  local kinds = {}
  for _, kind in pairs(DiffKind) do
    local symbol = diff_kinds.kind_symbols[kind]
    if symbol then
      kinds[kind] = _pattern(marker, "%" .. symbol)
    end
  end

  local function section_header(line)
    for kind, pattern in pairs(kinds) do
      local s, _, _, label = string.find(line, pattern)
      if s then
        return kind, label
      end
    end
    return nil
  end

  ---@type Section[]
  local sections = {}
  local section_start = marker.start_line + 1
  local section_label = nil
  local section_kind = nil
  local section_lines = {}

  local function handle()
    if section_kind then
      sections[#sections + 1] = {
        label = section_label,
        kind = section_kind,
        header_line = section_start,
        content_line = section_start + 1,
        lines = section_lines,
      }
    else
      sections[#sections + 1] = {
        label = section_label,
        kind = DiffKind.DIFF3_LEFT,
        header_line = nil,
        content_line = section_start,
        lines = section_lines,
      }
    end
  end

  for i, line in ipairs(lines) do
    local kind, label = section_header(line)
    if kind then
      -- Found a section header.
      if
        kind ~= DiffKind.DIFF3_BASE
        and kind ~= DiffKind.DIFF3_RIGHT
        and not section_kind
      then
        -- Not a diff3 section, so no initial text section. Skip.
      else
        handle()
      end
      section_start = marker.start_line + i
      section_label = label
      section_kind = kind
      section_lines = {}
    else
      section_lines[#section_lines + 1] = line
    end
  end
  -- Handle last section.
  handle()

  return sections
end

---@param buffer_lines string[]
---@return Marker[]
function M.extract_diff_markers(buffer_lines)
  ---@type Marker[]
  local markers = {}

  ---@type Marker|nil
  local marker = nil
  local marker_lines = {}
  for i, line in ipairs(buffer_lines) do
    if not marker then
      -- Detect start of a marker.
      local s, _, prefix, label = string.find(line, "^(<<<<<<<<*) (.*)")
      if s then
        -- Found a marker.
        marker = {
          start_line = i - 1,
          end_line = -1,
          label = label,
          end_label = "",
          prefix_len = #prefix,
          sections = {},
        }
      end
      goto continue
    end

    -- Inside a marker.
    -- Detect end of marker.
    local s, _, _, label = string.find(line, _pattern(marker, ">"))
    if s then
      -- End of marker, finalize it.
      marker.end_line = i
      marker.end_label = label or ""
      marker.sections = _extract_sections(marker, marker_lines)
      markers[#markers + 1] = marker
      marker = nil
      marker_lines = {}
      goto continue
    end

    marker_lines[#marker_lines + 1] = line

    ::continue::
  end

  return markers
end

---@param marker Marker
---@return Interval
function M.to_interval(marker)
  return {
    l = marker.start_line,
    r = marker.end_line,
    data = marker,
  }
end

--- Get the `count`th previous marker.
---@param lnum integer
---@param markers Marker[]
---@param count integer
---@return Marker?
function M.prev_marker(lnum, markers, count)
  return intervals.from_list(markers, M.to_interval):find(lnum, -count)
end

--- Get the `count`th next marker.
---@param lnum integer
---@param markers Marker[]
---@param count integer
---@return Marker?
function M.next_marker(lnum, markers, count)
  return intervals.from_list(markers, M.to_interval):find(lnum, count)
end

--- Get the current marker for a given line number, if any.
---@param lnum integer
---@param markers Marker[]
---@return Marker?
function M.cur_marker(lnum, markers)
  return intervals.from_list(markers, M.to_interval):find(lnum, 0)
end

-- Re-export the marker format functions.
M.cycle_marker = marker_format.cycle_marker
M.materialize_marker = marker_format.materialize_marker

return M
