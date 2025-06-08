local M = {}

---@enum DiffKind
M.DiffKind = {
  DIFF = "diff",
  ADDED = "add",
  DELETED = "del",
  DIFF3_LEFT = "diff3_left",
  DIFF3_BASE = "diff3_base",
  DIFF3_RIGHT = "diff3_right",
}

M.kind_symbols = {
  [M.DiffKind.DIFF] = "%",
  [M.DiffKind.ADDED] = "+",
  [M.DiffKind.DELETED] = "-",
  [M.DiffKind.DIFF3_BASE] = "|",
  [M.DiffKind.DIFF3_RIGHT] = "=",
  [M.DiffKind.DIFF3_LEFT] = nil,
}

return M
