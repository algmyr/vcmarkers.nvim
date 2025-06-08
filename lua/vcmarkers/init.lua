local M = {}

M.fold = require "vcmarkers.fold"
M.actions = require "vcmarkers.actions"

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

local function _with_count(fun)
  local function wrap(bufnr, args)
    if #args > 1 then
      error "This VCMarkers command takes at most one argument"
    end
    local count = tonumber(args[1]) or 1
    fun(bufnr, count)
  end
  return wrap
end

local command_map = {
  start = _no_args(M.actions.start),
  stop = _no_args(M.actions.stop),
  prev_marker = _with_count(M.actions.prev_marker),
  next_marker = _with_count(M.actions.next_marker),
  select = _no_args(M.actions.select_section),
  fold = _no_args(M.fold.toggle),
  cycle = _no_args(M.actions.cycle_marker),
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

local default_config = {
  -- Enable in all buffers by default.
  auto_enable = true,
  -- Sizes of context to add fold levels for (order doesn't matter).
  -- E.g. { 1, 3 } would mean one fold level with a context of 1 line,
  -- and one fold level with a context of 3 lines.
  fold_context_sizes = { 1 },
}

function M.setup(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  vim.g.vcmarkers_fold_context_sizes = config.fold_context_sizes

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

  if config.auto_enable then
    -- Enable VCMarkers for all buffers.
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*",
      callback = function(args)
        -- Try starting, will do nothing if markers are not present.
        M.actions.start(args.buf)
      end,
      desc = "Auto-enable VCMarkers on buffer read (if markers are present)",
    })
  end
end

return M
