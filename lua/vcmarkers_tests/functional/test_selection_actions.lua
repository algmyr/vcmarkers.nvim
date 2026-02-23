local M = {}

local helpers = require "vcmarkers_tests.functional.helpers"
local actions = require "vcmarkers.actions"
local testing = require "vclib.testing"

local basic_jj_conflict = [[
before
<<<<<<< Conflict 1
%%%%%%% diff
-first conflict old
+first conflict new 1
+++++++ snapshot
first conflict new 2
>>>>>>> Conflict 1 ends
after
]]

-- Section selection tests.
M.select = {
  test_cases = {
    select_first_section = {
      line = 5,
      expected = [[
        before
        -first conflict old
        +first conflict new 1
        after
      ]],
      action = actions.select_section,
    },
    select_second_section = {
      line = 6,
      expected = [[
        before
        first conflict new 2
        after
      ]],
      action = actions.select_section,
    },
    -- select_section_verbatim is an alias for select_section
    select_verbatim_first_section = {
      line = 5,
      expected = [[
        before
        -first conflict old
        +first conflict new 1
        after
      ]],
      action = actions.select_section_verbatim,
    },
    select_verbatim_second_section = {
      line = 6,
      expected = [[
        before
        first conflict new 2
        after
      ]],
      action = actions.select_section_verbatim,
    },
    select_plus_first_section = {
      line = 5,
      expected = [[
        before
        first conflict new 1
        after
      ]],
      action = actions.select_section_plus,
    },
    select_plus_second_section = {
      line = 6,
      expected = [[
        before
        first conflict new 2
        after
      ]],
      action = actions.select_section_verbatim,
    },
    select_all_first_section = {
      line = 5,
      expected = [[
        before
        first conflict new 1
        first conflict new 2
        after
      ]],
      action = actions.select_all_plus,
    },
    select_all_second_section = {
      line = 6,
      expected = [[
        before
        first conflict new 1
        first conflict new 2
        after
      ]],
      action = actions.select_all_plus,
    },
  },
  test = function(case)
    local bufnr = helpers.create_buffer(basic_jj_conflict)

    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    helpers.set_cursor(case.line, 0)
    case.action(bufnr)

    testing.assert_list_eq(
      helpers.get_lines(bufnr),
      testing.dedent_into_lines(case.expected)
    )
    helpers.assert_cursor_at(2, "Cursor should be at replacement start")

    helpers.cleanup_buffer(bufnr)
  end,
}

return M
