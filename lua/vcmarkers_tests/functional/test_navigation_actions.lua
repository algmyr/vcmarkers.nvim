local M = {}

local helpers = require "vcmarkers_tests.functional.helpers"
local actions = require "vcmarkers.actions"

local multi_marker_content = [[
line 1
<<<<<<< Conflict 1
%%%%%%% diff
-first conflict old
+first conflict new 1
+++++++ snapshot
first conflict new 2
>>>>>>> Conflict 1 ends
line 9
<<<<<<< Conflict 2
+++++++ snapshot
second conflict new 1
%%%%%%% diff
-second conflict old
+second conflict new 2
>>>>>>> Conflict 2 ends
line 17
]]

M.file_contents_sanity_check = {
  test_cases = {
    basic = "Basic integrity checks",
  },
  test = function(case)
    local bufnr = helpers.create_buffer(multi_marker_content)
    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    -- Should have 2 markers.
    local markers = vim.b[bufnr].vcmarkers_markers
    local count = markers and #markers or 0
    assert(count == 2, "Expected 2 markers, got " .. count)

    helpers.cleanup_buffer(bufnr)
  end,
}

M.marker_navigation_forward = {
  test_cases = {
    before = { 1, 2 },
    start_1 = { 2, 10 },
    middle1 = { 5, 10 },
    endof_1 = { 8, 10 },
    between = { 9, 10 },
    start_2 = { 10, 10 },
    middle2 = { 13, 13 },
    endof_2 = { 16, 16 },
    after = { 17, 17 },
  },
  test = function(case)
    local start_line = case[1]
    local expected_line = case[2]
    local bufnr = helpers.create_buffer(multi_marker_content)
    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    helpers.set_cursor(start_line, 0)
    actions.next_marker(bufnr, 1)
    helpers.assert_cursor_at(expected_line)
    helpers.cleanup_buffer(bufnr)
  end,
}

M.marker_navigation_backward = {
  test_cases = {
    before = { 1, 1 },
    start_1 = { 2, 2 },
    middle1 = { 5, 5 },
    endof_1 = { 8, 8 },
    between = { 9, 2 },
    start_2 = { 10, 2 },
    middle2 = { 13, 2 },
    endof_2 = { 16, 2 },
    after = { 17, 10 },
  },
  test = function(case)
    local start_line = case[1]
    local expected_line = case[2]
    local bufnr = helpers.create_buffer(multi_marker_content)
    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    helpers.set_cursor(start_line, 0)
    actions.prev_marker(bufnr, 1)
    helpers.assert_cursor_at(expected_line)
    helpers.cleanup_buffer(bufnr)
  end,
}

M.marker_navigation_complex = {
  test_cases = {
    twice_forward = {
      start_line = 1,
      expected_line = 10,
      action = function(bufnr)
        actions.next_marker(bufnr, 2)
      end,
    },
    twice_backward = {
      start_line = 17,
      expected_line = 2,
      action = function(bufnr)
        actions.prev_marker(bufnr, 2)
      end,
    },
  },
  test = function(case)
    local bufnr = helpers.create_buffer(multi_marker_content)

    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    helpers.set_cursor(case.start_line, 0)

    case.action(bufnr)
    helpers.assert_cursor_at(case.expected_line)

    helpers.cleanup_buffer(bufnr)
  end,
}

return M
