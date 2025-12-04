local M = {}

local diff_kinds = require "vcmarkers.diff_kinds"

local DiffKind = diff_kinds.DiffKind

local util = require "vcmarkers.util"

---@param lines string[]
---@param symbol string
---@param prefix_len integer
---@param label string[]
local function _add_marker_lines(lines, symbol, prefix_len, label)
  if #label > 0 then
    lines[#lines + 1] = string.rep(symbol, prefix_len) .. " " .. label[1]
    -- JJ continuation lines.
    for i = 2, #label do
      lines[#lines + 1] = string.rep("\\", prefix_len) .. " " .. label[i]
    end
  else
    lines[#lines + 1] = string.rep(symbol, prefix_len)
  end
end

---@param section Section
---@return string[]
local function _materialize_section(section, prefix_len)
  --@type string[]
  local lines = {}
  local symbol = diff_kinds.section_symbols[section.kind]
  if symbol then
    _add_marker_lines(lines, symbol, prefix_len, section.label)
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
  _add_marker_lines(lines, "<", marker.prefix_len, marker.label)
  for _, section in ipairs(marker.sections) do
    util.extend(lines, _materialize_section(section, marker.prefix_len))
  end
  _add_marker_lines(lines, ">", marker.prefix_len, marker.end_label)
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

---@param label string[]
---@return boolean
local function _is_legacy_label(label)
  if not label or #label ~= 1 then
    return false
  end
  -- Legacy labels are single-line and match patterns like:
  -- "Contents of side #N", "Contents of base", "Changes from base to side #N".
  local text = label[1]
  return (text:match "^Contents of " or text:match "^Changes from ")
end

---@param label string[]
---@return string[]
local function _drop_legacy_label(label)
  if _is_legacy_label(label) then
    return {}
  end
  return label
end

---@param sides Side[]
---@return Section[]
local function _snapshot_sections(sides)
  ---@type Section[]
  local sections = {}
  local base = _base_label_gen(_num_sides(sides))
  local side = _side_label_gen()
  for i, side_data in ipairs(sides) do
    local kind
    local default_label
    if i % 2 == 0 then
      kind = DiffKind.DELETED
      default_label = "Contents of " .. base()
    else
      kind = DiffKind.ADDED
      default_label = "Contents of " .. side()
    end

    -- Use original label if available, otherwise use default.
    local section_label = side_data.label
    if not section_label or #section_label == 0 then
      section_label = { default_label }
    end

    sections[#sections + 1] = {
      label = section_label,
      kind = kind,
      header_line = nil, -- Computed later.
      content_line = -1, -- Computed later.
      lines = side_data.lines,
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

---@param sides Side[]
---@return Section[]
local function _diff_sections(sides, plus_index)
  ---@type Section[]
  local sections = {}

  local base = _base_label_gen(_num_sides(sides))
  local side = _side_label_gen()

  local function _diff_section(plus_side, minus_side)
    local default_label = { "Changes from " .. base() .. " to " .. side() }
    local section_label

    local plus_label = plus_side.label
    local minus_label = minus_side.label

    if plus_label and minus_label and #plus_label > 0 and #minus_label > 0 then
      -- New style label.
      -- These should be true, but assert just in case.
      assert(#plus_label == 1)
      assert(#minus_label == 1)

      -- Format new style label.
      section_label = {
        "diff from: " .. minus_label[1],
        "       to: " .. plus_label[1],
      }
    else
      -- Generate legacy style label.
      section_label = default_label
    end

    return {
      label = section_label,
      kind = DiffKind.DIFF,
      header_line = nil, -- Computed later.
      content_line = -1, -- Computed later.
      lines = _build_diff_lines(minus_side.lines, plus_side.lines),
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
  local snapshot_side = sides[side_index]
  local snapshot_label = snapshot_side.label
  if not snapshot_label or #snapshot_label == 0 then
    snapshot_label = { "Contents of " .. side() }
  else
    -- Advance the generator for consistency.
    side()
  end
  sections[#sections + 1] = {
    label = snapshot_label,
    kind = DiffKind.ADDED,
    header_line = nil, -- Computed later.
    content_line = -1, -- Computed later.
    lines = snapshot_side.lines,
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

---@class Side
---@field lines string[]
---@field label string[]

---@param label string[]
---@return string[], string[]
local function _extract_diff_labels(label)
  if not label or #label ~= 2 then
    -- Not a new style diff label (expected 2 lines) - fall back to defaults.
    return {}, {}
  end

  local from_text = label[1]:match "^diff from: (.+)$"
  local to_text = label[2]:match "^%s+to: (.+)$"
  if not from_text or not to_text then
    -- Some part looks malformed - fall back to defaults.
    return {}, {}
  end
  return { to_text }, { from_text }
end

---@param jj_marker Marker
---@return Side[], integer|nil
local function _deconstruct_marker(jj_marker)
  local plus_index = nil
  local is_snapshot = true
  local plus_sides = {}
  local minus_sides = {}

  for i, section in ipairs(jj_marker.sections) do
    if section.kind == DiffKind.ADDED then
      plus_sides[#plus_sides + 1] =
        { lines = section.lines, label = _drop_legacy_label(section.label) }
      plus_index = i
    elseif section.kind == DiffKind.DELETED then
      minus_sides[#minus_sides + 1] =
        { lines = section.lines, label = _drop_legacy_label(section.label) }
    elseif section.kind == DiffKind.DIFF then
      is_snapshot = false
      -- Extract both plus and minus labels from the diff label.
      local plus_label, minus_label = _extract_diff_labels(section.label)
      plus_sides[#plus_sides + 1] = {
        lines = _diff_extract_side(section.lines, "+"),
        label = plus_label,
      }
      minus_sides[#minus_sides + 1] = {
        lines = _diff_extract_side(section.lines, "-"),
        label = minus_label,
      }
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

---Return only the plus sections of a marker.
---@param marker Marker
---@return Side[]
function M.plus_sections(marker)
  local sides, _ = _deconstruct_marker(marker)
  local plus_sides = {}
  for i = 1, #sides, 2 do
    plus_sides[#plus_sides + 1] = sides[i]
  end
  return plus_sides
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
