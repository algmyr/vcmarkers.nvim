local M = {}

local diff_kinds = require "vcmarkers.diff_kinds"
local marker_format = require "vcmarkers.marker_format"
local testing = require "vclib.testing"

local DiffKind = diff_kinds.DiffKind

---@param sections Section[]
---@return Marker
local function _make_marker(sections)
  return {
    end_label = "end_label",
    end_line = 42,
    label = "label",
    prefix_len = 4,
    sections = sections,
    start_line = 12,
  }
end

---@param kind string
---@param lines string[]
---@return Section
local function _make_section(kind, lines)
  return {
    content_line = 123,
    header_line = 456,
    kind = kind,
    label = nil,
    lines = lines,
  }
end

local simple_jj1 = _make_marker {
  _make_section(DiffKind.ADDED, { "apple", "grapefruit", "orange" }),
  _make_section(
    DiffKind.DIFF,
    { "-apple", "-grape", "-orange", "+APPLE", "+GRAPE", "+ORANGE" }
  ),
}
local simple_jj2 = _make_marker {
  _make_section(
    DiffKind.DIFF,
    { " apple", "-grape", "+grapefruit", " orange" }
  ),
  _make_section(DiffKind.ADDED, { "APPLE", "GRAPE", "ORANGE" }),
}
local simple_snapshot = _make_marker {
  _make_section(DiffKind.ADDED, { "apple", "grapefruit", "orange" }),
  _make_section(DiffKind.DELETED, { "apple", "grape", "orange" }),
  _make_section(DiffKind.ADDED, { "APPLE", "GRAPE", "ORANGE" }),
}

local empty_jj1 = _make_marker {
  _make_section(DiffKind.ADDED, {}),
  _make_section(DiffKind.DIFF, { "-grape", "+GRAPE" }),
}
local empty_jj2 = _make_marker {
  _make_section(DiffKind.DIFF, { "-grape" }),
  _make_section(DiffKind.ADDED, { "GRAPE" }),
}
local empty_snapshot = _make_marker {
  _make_section(DiffKind.ADDED, {}),
  _make_section(DiffKind.DELETED, { "grape" }),
  _make_section(DiffKind.ADDED, { "GRAPE" }),
}

---@param a Marker
---@param b Marker
local function _assert_marker_eq(a, b)
  assert(
    #a.sections == #b.sections,
    "Markers have different number of sections"
  )
  for i = 1, #a.sections do
    local a_section = a.sections[i]
    local b_section = b.sections[i]
    assert(a_section.kind == b_section.kind, "Section kinds differ")
    testing.assert_list_eq(a_section.lines, b_section.lines)
  end
end

local _generate_cycle_cases = function(prefix, cycle)
  local cases = {}
  for steps = 1, #cycle do
    for i = 1, #cycle do
      local case = {
        cycles = steps,
        input = cycle[i],
        expected = cycle[(i + steps - 1) % #cycle + 1],
      }
      cases[string.format("%s_%d_%dsteps", prefix, i, steps)] = case
    end
  end
  return cases
end

M.content_cycles = {
  test_cases = vim.tbl_extend(
    "error",
    _generate_cycle_cases("simple", {
      simple_jj1,
      simple_jj2,
      simple_snapshot,
    }),
    _generate_cycle_cases("empty", {
      empty_jj1,
      empty_jj2,
      empty_snapshot,
    })
  ),
  test = function(case)
    local marker = case.input
    for _ = 1, case.cycles do
      marker = marker_format.cycle_marker(marker)
    end
    _assert_marker_eq(marker, case.expected)
  end,
}

return M
