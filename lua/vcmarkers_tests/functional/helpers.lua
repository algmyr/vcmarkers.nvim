local M = {}

local testing = require "vclib.testing"

--- Create a buffer with given contents.
---@param contents string Multiline string to set in buffer.
---@return integer bufnr The buffer number.
function M.create_buffer(contents)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = testing.dedent_into_lines(contents)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

--- Set cursor position.
---@param line integer Line number (1-indexed).
---@param col? integer Column number (0-indexed), defaults to 0.
function M.set_cursor(line, col)
  col = col or 0
  vim.api.nvim_win_set_cursor(0, { line, col })
end

--- Assert cursor is at specific line.
---@param expected_line integer Expected line number (1-indexed).
---@param msg? string Optional error message.
function M.assert_cursor_at(expected_line, msg)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  msg = msg or "Expected cursor at line " .. expected_line .. ", got " .. line
  assert(line == expected_line, msg)
end

--- Wait a bit for async updates to settle.
---@param ms? integer Milliseconds to wait (default 10).
function M.wait_update(ms)
  ms = ms or 10
  vim.wait(ms, function()
    return false
  end)
  -- Process pending events
  vim.api.nvim_exec_autocmds("User", { pattern = "Wait" })
end

--- Get buffer lines.
---@param bufnr integer Buffer number.
---@return string[] lines The buffer lines.
function M.get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

--- Clean up buffer.
---@param bufnr integer Buffer number.
function M.cleanup_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

return M
