local M = {}

local testing = require "vclib.testing"

function M.run()
  local test_modules = {
    "vcmarkers_tests.cycle_contents",
    "vcmarkers_tests.marker_format",
    "vcmarkers_tests.cycle_labels",
  }
  testing.run_tests(test_modules)
end

return M
