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
  local symbol = diff_kinds.section_symbols[section.kind]
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

local function _num_sides(sides)
  return math.floor(#sides / 2) + 1
end

local function _base_label_gen(num_sides)
  if num_sides == 2 then
    return function()
      return "base"
    end
  else
    local index = 0
    return function()
      index = index + 1
      return "base #" .. index
    end
  end
end

local function _side_label_gen()
  local index = 0
  return function()
    index = index + 1
    return "side #" .. index
  end
end

---@param base string[]
---@param sides string[][]
---@return Section[]
local function _snapshot_sections(sides)
  ---@type Section[]
  local sections = {}
  local base = _base_label_gen(_num_sides(sides))
  local side = _side_label_gen()
  for i, lines in ipairs(sides) do
    local label
    local kind
    if i % 2 == 0 then
      label = string.format("Contents of " .. base())
      kind = DiffKind.DELETED
    else
      label = string.format("Contents of " .. side())
      kind = DiffKind.ADDED
    end

    sections[#sections + 1] = {
      label = label,
      kind = kind,
      header_line = nil, -- Computed later.
      content_line = -1, -- Computed later.
      lines = lines,
    }
  end
  return sections
end

---@param lines string[]
---@return string
local function _join_lines(lines)
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n") .. "\n"
end

local function _build_diff_lines(base, side)
  -- Join lines into one string
  local base_str = _join_lines(base)
  local side_str = _join_lines(side)
  local diff_str = vim.diff(base_str, side_str, {
    ctxlen = 100000,
    algorithm = "histogram",
  })
  ---@cast diff_str string
  local diff_lines = vim.split(diff_str, "\n", { plain = true })
  table.remove(diff_lines, 1) -- Diff header line.
  table.remove(diff_lines) -- Empty line at end.
  return diff_lines
end

---@param base string[]
---@param sides string[][]
---@return Section[]
local function _diff_sections(sides, plus_index)
  ---@type Section[]
  local sections = {}

  local base = _base_label_gen(_num_sides(sides))
  local side = _side_label_gen()

  local function _diff_section(plus, minus)
    return {
      label = "Changes from " .. base() .. " to " .. side(),
      kind = DiffKind.DIFF,
      header_line = nil, -- Computed later.
      content_line = -1, -- Computed later.
      lines = _build_diff_lines(minus, plus),
    }
  end

  local side_index = 1
  -- Diffs.
  for _ = 1, plus_index - 1 do
    sections[#sections + 1] =
      _diff_section(sides[side_index], sides[side_index + 1])
    side_index = side_index + 2
  end
  -- Snapshot.
  sections[#sections + 1] = {
    label = "Contents of " .. side(),
    kind = DiffKind.ADDED,
    header_line = nil, -- Computed later.
    content_line = -1, -- Computed later.
    lines = sides[side_index],
  }
  side_index = side_index + 1
  -- Diff.
  for _ = plus_index + 1, _num_sides(sides) do
    sections[#sections + 1] =
      _diff_section(sides[side_index + 1], sides[side_index])
    side_index = side_index + 2
  end
  return sections
end

---@param jj_marker Marker
local function _deconstruct_marker(jj_marker)
  local plus_index = nil
  local is_snapshot = true
  local plus_sides = {}
  local minus_sides = {}
  for i, section in ipairs(jj_marker.sections) do
    if section.kind == DiffKind.ADDED then
      plus_sides[#plus_sides + 1] = section.lines
      plus_index = i
    elseif section.kind == DiffKind.DELETED then
      minus_sides[#minus_sides + 1] = section.lines
    elseif section.kind == DiffKind.DIFF then
      is_snapshot = false
      plus_sides[#plus_sides + 1] = _diff_extract_side(section.lines, "+")
      minus_sides[#minus_sides + 1] = _diff_extract_side(section.lines, "-")
    end
  end

  if #plus_sides ~= #minus_sides + 1 then
    error "Inconsistent number of plus and minus sides."
  end
  local sides = {}
  for i = 1, #minus_sides do
    sides[#sides + 1] = plus_sides[i]
    sides[#sides + 1] = minus_sides[i]
  end
  sides[#sides + 1] = plus_sides[#plus_sides]

  if is_snapshot then
    return sides, nil
  else
    return sides, plus_index
  end
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

  local sides, plus_index = _deconstruct_marker(jj_marker)

  local num_sides = _num_sides(sides)
  if plus_index == num_sides then
    -- Plus last section -> Snapshot.
    jj_marker.sections = _snapshot_sections(sides)
  else
    if not plus_index then
      -- Snapshot -> Plus first section.
      plus_index = 1
    else
      plus_index = plus_index + 1
    end
    jj_marker.sections = _diff_sections(sides, plus_index)
  end
  _fix_section_numbers(jj_marker)
  return jj_marker
end

return M
