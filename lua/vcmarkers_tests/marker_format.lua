local M = {}

local diff_kinds = require "vcmarkers.diff_kinds"
local markers = require "vcmarkers.markers"
local marker_format = require "vcmarkers.marker_format"
local testing = require "vclib.testing"

local function _assert_eq(a, b, msg)
  assert(a == b, msg .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local DiffKind = diff_kinds.DiffKind

---@param a Marker
---@param b Marker
local function _assert_marker_eq(a, b)
  _assert_eq(a.start_line, b.start_line, "Start lines differ")
  _assert_eq(a.end_line, b.end_line, "End lines differ")
  _assert_eq(a.label, b.label, "Labels differ")
  _assert_eq(a.end_label, b.end_label, "End labels differ")
  _assert_eq(a.prefix_len, b.prefix_len, "Prefix lengths differ")
  _assert_eq(
    #a.sections,
    #b.sections,
    "Markers have different number of sections"
  )
  for i = 1, #a.sections do
    local a_section = a.sections[i]
    local b_section = b.sections[i]
    _assert_eq(a_section.label, b_section.label, "Section labels differ")
    _assert_eq(a_section.kind, b_section.kind, "Section kinds differ")
    _assert_eq(
      a_section.header_line,
      b_section.header_line,
      "Section header lines differ"
    )
    _assert_eq(
      a_section.content_line,
      b_section.content_line,
      "Section content lines differ"
    )
    testing.assert_list_eq(a_section.lines, b_section.lines)
  end
end

local function _parse_lines(s)
  local l = 1
  while s:sub(l, l) == "\n" do
    l = l + 1
  end
  local r = #s
  while true do
    local c = s:sub(r, r)
    if c ~= "\n" and c ~= " " then
      break
    end
    r = r - 1
  end
  local stripped = s:sub(l, r)
  local lines = vim.split(stripped, "\n", { plain = true })
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    local indent = #line - #line:gsub("^%s*", "")
    if #line > 0 and indent < min_indent then
      min_indent = indent
    end
  end
  if min_indent == math.huge then
    min_indent = 0
  end
  for i, line in ipairs(lines) do
    lines[i] = line:sub(min_indent + 1)
  end
  return lines
end

M.parsing = {
  test_cases = {
    jj_diff = {
      text = [[
        before
        <<<<<<< marker label
        %%%%%%% diff label
        -apple
        +APPLE
        +++++++ snapshot label
        orange
        >>>>>>> end marker label
        after
      ]],
      expected_markers = {
        {
          start_line = 1, -- zero-based
          end_line = 8,
          label = "marker label",
          end_label = "end marker label",
          prefix_len = 7,
          sections = {
            {
              label = "diff label",
              kind = DiffKind.DIFF,
              header_line = 2,
              content_line = 3,
              lines = { "-apple", "+APPLE" },
            },
            {
              label = "snapshot label",
              kind = DiffKind.ADDED,
              header_line = 5,
              content_line = 6,
              lines = { "orange" },
            },
          },
        },
      },
    },
    jj_snapshot = {
      text = [[
        before
        <<<<<<< marker label
        +++++++ snapshot label 1
        APPLE
        ------- snapshot label 2
        apple
        +++++++ snapshot label 3
        orange
        >>>>>>> end marker label
        after
      ]],
      expected_markers = {
        {
          start_line = 1, -- zero-based
          end_line = 9,
          label = "marker label",
          end_label = "end marker label",
          prefix_len = 7,
          sections = {
            {
              label = "snapshot label 1",
              kind = DiffKind.ADDED,
              header_line = 2,
              content_line = 3,
              lines = { "APPLE" },
            },
            {
              label = "snapshot label 2",
              kind = DiffKind.DELETED,
              header_line = 4,
              content_line = 5,
              lines = { "apple" },
            },
            {
              label = "snapshot label 3",
              kind = DiffKind.ADDED,
              header_line = 6,
              content_line = 7,
              lines = { "orange" },
            },
          },
        },
      },
    },
    -- TODO: Add more test cases.
  },
  test = function(case)
    local lines = _parse_lines(case.text)
    local ms = markers.extract_diff_markers(lines)
    _assert_eq(#ms, #case.expected_markers, "Number of markers differ")
    for i = 1, #ms do
      _assert_marker_eq(ms[i], case.expected_markers[i])
    end
  end,
}

M.roundtrip = {
  test_cases = {
    jj_diff = {
      text = [[
        <<<<<<< marker label
        %%%%%%% diff label
        -apple
        +APPLE
        +++++++ snapshot label
        orange
        >>>>>>> end marker label
      ]],
    },
    jj_snapshot = {
      text = [[
        <<<<<<< marker label
        +++++++ snapshot label 1
        APPLE
        ------- snapshot label 2
        apple
        +++++++ snapshot label 3
        orange
        >>>>>>> end marker label
      ]],
    },
    -- Markers from docs and miscellaneous others.
    jj_empty_section = {
      text = [[
        <<<<<<< Conflict 1 of 1
        +++++++ Contents of side #1
        %%%%%%% Changes from base to side #2
        -grape
        +GRAPE
        >>>>>>> Conflict 1 of 1 ends
      ]],
    },
    jj_diff_2 = {
      text = [[
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
      ]],
    },
    jj_snapshot_2 = {
      text = [[
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
      ]],
    },
    git_diff3 = {
      text = [[
        <<<<<<< Side #1 (Conflict 1 of 1)
        apple
        grapefruit
        orange
        ||||||| Base
        apple
        grape
        orange
        =======
        APPLE
        GRAPE
        ORANGE
        >>>>>>> Side #2 (Conflict 1 of 1 ends)
      ]],
    },
    jj_long_prefix = {
      text = [[
        <<<<<<<<<<<<<<< Conflict 1 of 1
        %%%%%%%%%%%%%%% Changes from base to side #1
        -Heading
        +HEADING
         =======
        +++++++++++++++ Contents of side #2
        New Heading
        ===========
        >>>>>>>>>>>>>>> Conflict 1 of 1 ends
      ]],
    },
    jj_no_nl = {
      text = [[
        <<<<<<< Conflict 1 of 1
        +++++++ Contents of side #1 (no terminating newline)
        grapefruit
        %%%%%%% Changes from base to side #2 (adds terminating newline)
        -grape
        +grape
        >>>>>>> Conflict 1 of 1 ends
      ]],
    },
    git_diff = {
      text = [[
        <<<<<<< HEAD
        apple
        grapefruit
        orange
        =======
        apple
        >>>>>>>
      ]],
    },
  },
  test = function(case)
    local lines = _parse_lines(case.text)
    local ms = markers.extract_diff_markers(lines)
    assert(#ms == 1, "Expected exactly one marker")
    local reconstructed_lines = marker_format.materialize_marker(ms[1])
    testing.assert_list_eq(reconstructed_lines, lines)
  end,
}

return M
