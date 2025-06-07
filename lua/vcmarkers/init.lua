local M = {}

local actions = require "jjmarkers.actions"

--- Decorator to wrap a function that takes no arguments.
local function _no_args(fun)
  local function wrap(bufnr, args)
    if #args > 0 then
      error "This VCMarkers command does not take any arguments"
    end
    fun(bufnr)
  end
  return wrap
end

local command_map = {
  start = _no_args(actions.start),
  stop = _no_args(actions.stop),
}

local function _command(arg)
  local bufnr = vim.api.nvim_get_current_buf()
  local cmd = arg.fargs[1]
  local args = vim.list_slice(arg.fargs, 2)

  local fun = command_map[cmd]
  if not fun then
    error("Unknown VCMarkers command: " .. cmd)
    return
  end
  fun(bufnr, args)
end

function M.setup(opts)
  vim.api.nvim_create_user_command("VCMarkers", _command, {
    desc = "VCMarkers command",
    nargs = "*",
    bar = true,
    complete = function(_, line)
      if line:match "^%s*VCMarkers %w+ " then
        return {}
      end
      local prefix = line:match "^%s*VCMarkers (%w*)" or ""
      return vim.tbl_filter(function(key)
        return key:find(prefix) == 1
      end, vim.tbl_keys(command_map))
    end,
  })

  -- Set default highlights.
  -- The default diff colors are used for highlights.
  vim.cmd [[
    highlight default link VCMarkersMarker         SignColumn
    highlight default link VCMarkersSectionHeader  SignColumn
  ]]
end

return M
