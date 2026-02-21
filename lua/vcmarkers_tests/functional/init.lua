local M = {}

local testing = require "vclib.testing"

function M.run()
  local test_modules = {
    "vcmarkers_tests.functional.test_navigation_actions",
    "vcmarkers_tests.functional.test_selection_actions",
    "vcmarkers_tests.functional.test_cycling_actions",
  }
  testing.run_tests(test_modules)
end

return M
