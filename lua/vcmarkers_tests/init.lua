local M = {}

local testing = require "vclib.testing"

function M.run()
  local test_modules = {
    "vcmarkers_tests.cycle",
    "vcmarkers_tests.marker_format",
  }
  testing.run_tests(test_modules)
end

return M
