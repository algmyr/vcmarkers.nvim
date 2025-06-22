local M = {}

local diff_kinds = require "vcmarkers.diff_kinds"

local DiffKind = diff_kinds.DiffKind

local util = require "vcmarkers.util"

---@param symbol string
---@param prefix_len integer
---@param label string
local function _marker_line(symbol, prefix_len, label)
  if label ~= "" then
    return string.rep(symbol, prefix_len) .. " " .. label
  else
    return string.rep(symbol, prefix_len)
  end
end

---@param section Section
---@return string[]
local function _materialize_section(section, prefix_len)
  --@type string[]
  local lines = {}
  local symbol = diff_kinds.kind_symbols[section.kind]
  if symbol then
    lines[#lines + 1] = _marker_line(symbol, prefix_len, section.label)
  end
  for _, line in ipairs(section.lines) do
    lines[#lines + 1] = line
  end
  return lines
end

--- Materialize a marker into a list of lines.
---@param marker Marker
function M.materialize_marker(marker)
  ---@type string[]
  local lines = {}
  lines[#lines + 1] = _marker_line("<", marker.prefix_len, marker.label)
  for _, section in ipairs(marker.sections) do
    util.extend(lines, _materialize_section(section, marker.prefix_len))
  end
  lines[#lines + 1] = _marker_line(">", marker.prefix_len, marker.end_label)
  return lines
end

--- Fix line numbering of sections.
---@param marker Marker
local function _fix_section_numbers(marker)
  local line = marker.start_line + 1
  for _, section in ipairs(marker.sections) do
    section.header_line = line
    section.content_line = line + 1
    line = line + #section.lines + 1
  end
end

---@param lines string[]
---@return string[]
local function _diff_extract_side(lines, sign)
  local result = {}
  for _, line in ipairs(lines) do
    local c = string.sub(line, 1, 1)
    if c == " " or c == sign then
      result[#result + 1] = string.sub(line, 2)
    end
  end
  return result
end

---@param base string[]
---@param sides string[][]
---@return Section[]
local function _snapshot_sections(base, sides)
  ---@type Section[]
  local sections = {}
  for i, side in ipairs(sides) do
    sections[#sections + 1] = {
      label = "Contents of side #" .. i,
      kind = DiffKind.ADDED,
      header_line = nil, -- Computed later.
      content_line = -1, -- Computed later.
      lines = side,
    }
  end
  table.insert(sections, 2, {
    label = "Contents of base",
    kind = DiffKind.DELETED,
    header_line = nil, -- Computed later.
    content_line = -1, -- Computed later.
    lines = base,
  })
  return sections
end

---@param base string[]
---@param sides string[][]
---@return Section[]
local function _diff_sections(base, sides, plus_index)
  ---@type Section[]
  local sections = {}
  for i, side in ipairs(sides) do
    if i == plus_index then
      sections[#sections + 1] = {
        label = "Contents of side #" .. i,
        kind = DiffKind.ADDED,
        header_line = nil, -- Computed later.
        content_line = -1, -- Computed later.
        lines = side,
      }
    else
      -- Diff section.
      -- Join lines into one string
      local base_str = table.concat(base, "\n") .. "\n"
      local side_str = table.concat(side, "\n") .. "\n"
      local diff_str = vim.diff(base_str, side_str, {
        ctxlen = 100000,
        algorithm = "histogram",
      })
      ---@cast diff_str string
      local diff_lines = vim.split(diff_str, "\n", { plain = true })
      table.remove(diff_lines, 1) -- Diff header line.
      table.remove(diff_lines) -- Empty line at end.

      sections[#sections + 1] = {
        label = "Changes from base to side #" .. i,
        kind = DiffKind.DIFF,
        header_line = nil, -- Computed later.
        content_line = -1, -- Computed later.
        lines = diff_lines,
      }
    end
  end
  return sections
end

--- Cycle the marker format.
---@param jj_marker Marker
---@return Marker
function M.cycle_marker(jj_marker)
  jj_marker = vim.deepcopy(jj_marker)
  for _, section in ipairs(jj_marker.sections) do
    if
      section.kind == DiffKind.DIFF3_LEFT
      or section.kind == DiffKind.DIFF3_BASE
      or section.kind == DiffKind.DIFF3_RIGHT
    then
      error "Diff3 is not supported for this operation."
    end
  end

  local base = nil
  local sides = {}
  local plus_index = nil
  local is_snapshot = false
  for i, section in ipairs(jj_marker.sections) do
    if section.kind == DiffKind.ADDED then
      sides[#sides + 1] = section.lines
      plus_index = i
    elseif section.kind == DiffKind.DELETED then
      is_snapshot = true
      if not base then
        base = section.lines
      else
        error "Multiple deleted sections found, cannot convert to snapshots."
      end
    elseif section.kind == DiffKind.DIFF then
      sides[#sides + 1] = _diff_extract_side(section.lines, "+")
      if not base then
        base = _diff_extract_side(section.lines, "-")
      else
        error "Multiple deleted sections found, cannot convert to snapshots."
      end
    end
  end

  if not base then
    error "No deleted section found, cannot convert to snapshots."
  end
  if not plus_index then
    -- This should not happen, but let's just be safe.
    error "No added section found, cannot convert to snapshots."
  end

  if plus_index == #sides then
    -- Plus last section -> Snapshot.
    jj_marker.sections = _snapshot_sections(base, sides)
  else
    if is_snapshot then
      -- Snapshot -> Plus first section.
      plus_index = 1
    else
      plus_index = plus_index + 1
    end
    jj_marker.sections = _diff_sections(base, sides, plus_index)
  end
  _fix_section_numbers(jj_marker)
  return jj_marker
end

return M
