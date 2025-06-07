local M = {}

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
---@field prefix_len integer
---@field sections Section[]

---@enum DiffKind
M.DiffKind = {
  DIFF = "diff",
  ADDED = "add",
  DELETED = "del",
  DIFF3_LEFT = "diff3_left",
  DIFF3_BASE = "diff3_base",
  DIFF3_RIGHT = "diff3_right",
}

---@param marker Marker
---@param lnum integer
---@return Section|nil
function M.current_section(marker, lnum)
  lnum = lnum - 1 -- Convert to zero-based line number.
  for _, section in ipairs(marker.sections) do
    if
      section.content_line <= lnum
      and lnum < section.content_line + #section.lines
    then
      return section
    end
  end
  return nil
end

---@param section Section
function M.is_diff(section)
  return section.kind == M.DiffKind.DIFF
end

---@param section Section
function M.is_plus(section)
  return (
    section.kind == M.DiffKind.ADDED
    or section.kind == M.DiffKind.DIFF3_LEFT
    or section.kind == M.DiffKind.DIFF3_RIGHT
  )
end

---@param section Section
function M.is_minus(section)
  return section.kind == M.DiffKind.DELETED
    or section.kind == M.DiffKind.DIFF3_BASE
end

local function _pattern(marker, kind)
  return "^(" .. string.rep(kind, marker.prefix_len) .. ") ?(.*)"
end

---@param marker Marker
---@param lines string[]
---@return Section[]
local function _extract_sections(marker, lines)
  local kinds = {
    [M.DiffKind.DIFF] = _pattern(marker, "%%"),
    [M.DiffKind.ADDED] = _pattern(marker, "%+"),
    [M.DiffKind.DELETED] = _pattern(marker, "%-"),
    [M.DiffKind.DIFF3_BASE] = _pattern(marker, "%|"),
    [M.DiffKind.DIFF3_RIGHT] = _pattern(marker, "%="),
  }

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
        kind = M.DiffKind.DIFF3_LEFT,
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
      if kind ~= M.DiffKind.DIFF3_BASE and not section_kind then
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
          prefix_len = #prefix,
          sections = {},
        }
      end
      goto continue
    end

    -- Inside a marker.
    -- Detect end of marker.
    local s, _, _, _ = string.find(line, _pattern(marker, ">"))
    if s then
      -- End of marker, finalize it.
      marker.end_line = i
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

---@param lnum integer
---@param markers Marker[]
local function _partition_markers(lnum, markers)
  local before = {}
  local on = nil
  local after = {}

  for _, marker in ipairs(markers) do
    local count = marker.end_line - marker.start_line
    -- Special case the current marker, do not include it in before/after.
    if marker.start_line <= lnum and lnum < marker.start_line + count then
      on = marker
      goto continue
    end
    if marker.start_line < lnum then
      table.insert(before, marker)
    end
    if marker.start_line > lnum then
      table.insert(after, marker)
    end
    ::continue::
  end

  return before, on, after
end

--- Get the `count`th previous marker.
---@param lnum integer
---@param markers Marker[]
---@param count integer
---@return Marker?
function M.prev_marker(lnum, markers, count)
  local before, _, _ = _partition_markers(lnum - 1, markers)
  return before[#before - (count - 1)] or before[1]
end

--- Get the `count`th next marker.
---@param lnum integer
---@param markers Marker[]
---@param count integer
---@return Marker?
function M.next_marker(lnum, markers, count)
  local _, _, after = _partition_markers(lnum - 1, markers)
  return after[count] or after[#after]
end

--- Get the current marker for a given line number, if any.
---@param lnum integer
---@param markers Marker[]
---@return Marker?
function M.cur_marker(lnum, markers)
  local _, on, _ = _partition_markers(lnum - 1, markers)
  return on
end

return M
