local M = {}

local testing = require "vclib.testing"

function M.run()
  local test_modules = {
    "vcmarkers_tests.cycle",
  }
  testing.run_tests(test_modules)
end

return M
