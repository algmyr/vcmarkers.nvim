local M = {}

local markers = require "vcmarkers.markers"
local marker_format = require "vcmarkers.marker_format"
local testing = require "vclib.testing"

---@param a Marker
---@param b Marker
local function _assert_marker_eq(a, b)
  assert(
    #a.sections == #b.sections,
    "Markers have different number of sections: "
      .. #a.sections
      .. " vs "
      .. #b.sections
  )
  for i = 1, #a.sections do
    local a_section = a.sections[i]
    local b_section = b.sections[i]
    assert(
      a_section.kind == b_section.kind,
      "Section "
        .. i
        .. " kinds differ: "
        .. a_section.kind
        .. " vs "
        .. b_section.kind
    )
    testing.assert_list_eq(
      a_section.label,
      b_section.label,
      "Section " .. i .. " labels differ"
    )
    testing.assert_list_eq(
      a_section.lines,
      b_section.lines,
      "Section " .. i .. " lines differ"
    )
  end
end

-- Test case: simple merge with labels
local merge_diff_text = [[
<<<<<<< conflict 1 of 1
%%%%%%% diff from: vpxusssl 38d49363 "description of base"
\\\\\\\        to: rtsqusxu 2768b0b9 "description of left"
-base
+left
+++++++ ysrnknol 7a20f389 "description of right"
right
>>>>>>> conflict 1 of 1 ends
]]

local merge_snapshot_text = [[
<<<<<<< conflict 1 of 1
+++++++ rtsqusxu 2768b0b9 "description of left"
left
------- vpxusssl 38d49363 "description of base"
base
+++++++ ysrnknol 7a20f389 "description of right"
right
>>>>>>> conflict 1 of 1 ends
]]

local merge_diff2_text = [[
<<<<<<< conflict 1 of 1
+++++++ rtsqusxu 2768b0b9 "description of left"
left
%%%%%%% diff from: vpxusssl 38d49363 "description of base"
\\\\\\\        to: ysrnknol 7a20f389 "description of right"
-base
+right
>>>>>>> conflict 1 of 1 ends
]]

-- Test case: rebase with labels
local rebase_diff_text = [[
<<<<<<< conflict 1 of 1
%%%%%%% diff from: vpxusssl 38d49363 "base" (parents of rebased commit)
\\\\\\\        to: rtsqusxu 2768b0b9 "left" (rebase destination)
-base
+left
+++++++ ysrnknol 7a20f389 "right" (rebased commit)
right
>>>>>>> conflict 1 of 1 ends
]]

local rebase_snapshot_text = [[
<<<<<<< conflict 1 of 1
+++++++ rtsqusxu 2768b0b9 "left" (rebase destination)
left
------- vpxusssl 38d49363 "base" (parents of rebased commit)
base
+++++++ ysrnknol 7a20f389 "right" (rebased commit)
right
>>>>>>> conflict 1 of 1 ends
]]

local rebase_diff2_text = [[
<<<<<<< conflict 1 of 1
+++++++ rtsqusxu 2768b0b9 "left" (rebase destination)
left
%%%%%%% diff from: vpxusssl 38d49363 "base" (parents of rebased commit)
\\\\\\\        to: ysrnknol 7a20f389 "right" (rebased commit)
-base
+right
>>>>>>> conflict 1 of 1 ends
]]

-- Test case: legacy format without labels
local legacy_diff_text = [[
<<<<<<< Conflict 1 of 1
%%%%%%% Changes from base to side #1
 apple
-grape
+grapefruit
 orange
+++++++ Contents of side #2
APPLE
GRAPE
ORANGE
>>>>>>> Conflict 1 of 1 ends
]]

local legacy_snapshot_text = [[
<<<<<<< Conflict 1 of 1
+++++++ Contents of side #1
apple
grapefruit
orange
------- Contents of base
apple
grape
orange
+++++++ Contents of side #2
APPLE
GRAPE
ORANGE
>>>>>>> Conflict 1 of 1 ends
]]

local legacy_diff2_text = [[
<<<<<<< Conflict 1 of 1
+++++++ Contents of side #1
apple
grapefruit
orange
%%%%%%% Changes from base to side #2
-apple
-grape
-orange
+APPLE
+GRAPE
+ORANGE
>>>>>>> Conflict 1 of 1 ends
]]

---@param text string
---@return Marker
local function _parse_marker(text)
  local lines = vim.split(text, "\n", { plain = true })
  local extracted = markers.extract_diff_markers(lines)
  assert(#extracted == 1, "Expected exactly one marker, got " .. #extracted)
  return extracted[1]
end

---@param marker Marker
---@return string
local function _materialize_marker(marker)
  local lines = marker_format.materialize_marker(marker)
  return table.concat(lines, "\n")
end

---@param input_text string
---@param expected_text string
---@param cycles integer
local function _test_cycle(input_text, expected_text, cycles)
  local marker = _parse_marker(input_text)

  for _ = 1, cycles do
    marker = marker_format.cycle_marker(marker)
  end

  local result_text = _materialize_marker(marker)
  local expected_marker = _parse_marker(expected_text)
  local result_marker = _parse_marker(result_text)

  _assert_marker_eq(result_marker, expected_marker)
end

M.merge_labels = {
  test_cases = {
    ["diff_to_snapshot"] = {
      input = merge_diff_text,
      expected = merge_snapshot_text,
      cycles = 1,
    },
    ["snapshot_to_diff2"] = {
      input = merge_snapshot_text,
      expected = merge_diff2_text,
      cycles = 1,
    },
    ["diff2_to_diff"] = {
      input = merge_diff2_text,
      expected = merge_diff_text,
      cycles = 1,
    },
    ["full_cycle"] = {
      input = merge_diff_text,
      expected = merge_diff_text,
      cycles = 3,
    },
  },
  test = function(case)
    _test_cycle(case.input, case.expected, case.cycles)
  end,
}

M.rebase_labels = {
  test_cases = {
    ["diff_to_snapshot"] = {
      input = rebase_diff_text,
      expected = rebase_snapshot_text,
      cycles = 1,
    },
    ["snapshot_to_diff2"] = {
      input = rebase_snapshot_text,
      expected = rebase_diff2_text,
      cycles = 1,
    },
    ["diff2_to_diff"] = {
      input = rebase_diff2_text,
      expected = rebase_diff_text,
      cycles = 1,
    },
    ["full_cycle"] = {
      input = rebase_diff_text,
      expected = rebase_diff_text,
      cycles = 3,
    },
  },
  test = function(case)
    _test_cycle(case.input, case.expected, case.cycles)
  end,
}

M.legacy_format = {
  test_cases = {
    ["diff_to_snapshot"] = {
      input = legacy_diff_text,
      expected = legacy_snapshot_text,
      cycles = 1,
    },
    ["snapshot_to_diff2"] = {
      input = legacy_snapshot_text,
      expected = legacy_diff2_text,
      cycles = 1,
    },
    ["diff2_to_diff"] = {
      input = legacy_diff2_text,
      expected = legacy_diff_text,
      cycles = 1,
    },
    ["full_cycle"] = {
      input = legacy_diff_text,
      expected = legacy_diff_text,
      cycles = 3,
    },
  },
  test = function(case)
    _test_cycle(case.input, case.expected, case.cycles)
  end,
}

return M
