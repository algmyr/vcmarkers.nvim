local M = {}

local helpers = require "vcmarkers_tests.functional.helpers"
local actions = require "vcmarkers.actions"
local testing = require "vclib.testing"

local basic_jj_conflict = [[
before
<<<<<<< conflict 1 of 1
%%%%%%% diff from: vpxusssl 38d49363 "description of base"
\\\\\\\        to: rtsqusxu 2768b0b9 "description of left"
-base
+left
+++++++ ysrnknol 7a20f389 "description of right"
right
>>>>>>> conflict 1 of 1 ends
after
]]

-- Marker cycling tests.

M.cycle_snapshot_to_diff = {
  test_cases = {
    cycle_1 = {
      expected = [[
        before
        <<<<<<< conflict 1 of 1
        +++++++ rtsqusxu 2768b0b9 "description of left"
        left
        ------- vpxusssl 38d49363 "description of base"
        base
        +++++++ ysrnknol 7a20f389 "description of right"
        right
        >>>>>>> conflict 1 of 1 ends
        after
      ]],
      count = 1,
    },
    cycle_2 = {
      expected = [[
        before
        <<<<<<< conflict 1 of 1
        +++++++ rtsqusxu 2768b0b9 "description of left"
        left
        %%%%%%% diff from: vpxusssl 38d49363 "description of base"
        \\\\\\\        to: ysrnknol 7a20f389 "description of right"
        -base
        +right
        >>>>>>> conflict 1 of 1 ends
        after
      ]],
      count = 2,
    },
    cycle_3 = {
      expected = [[
        before
        <<<<<<< conflict 1 of 1
        %%%%%%% diff from: vpxusssl 38d49363 "description of base"
        \\\\\\\        to: rtsqusxu 2768b0b9 "description of left"
        -base
        +left
        +++++++ ysrnknol 7a20f389 "description of right"
        right
        >>>>>>> conflict 1 of 1 ends
        after
      ]],
      count = 3,
    },
  },
  test = function(case)
    local bufnr = helpers.create_buffer(basic_jj_conflict)

    -- Enable marker detection.
    actions.start(bufnr)
    helpers.wait_update()

    helpers.set_cursor(3, 0)
    for _ = 1, case.count do
      actions.cycle_marker(bufnr)
    end

    testing.assert_list_eq(
      helpers.get_lines(bufnr),
      testing.dedent_into_lines(case.expected)
    )

    helpers.cleanup_buffer(bufnr)
  end,
}

return M
