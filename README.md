# VCMarkers.nvim

> [!WARNING]
> This is very much a WIP and bugs are likely.

Plugin that handles diff markers. Supports jj style diffs and diff3.

When started, the processing of diff markers will continue to auto-update until
there are no more diff markers in the file. By default the plugin tries to
start tracking on buffer load, but if needed tracking can also be manually
controlled using
```
VCMarkers start
VCMarkers stop
```

## Features

For all diff styles

* Diff marker highlighting.
* Navigation between markers.
  * `VCMarkers next_marker`
  * `VCMarkers prev_marker`
* Fold everything except markers + context.
  * `VCMarkers fold`
* "Select" the current section and replace the marker with it.
  * `VCMarkers select`

For jj style diffs

* Cycle through diff representations.
  * `VCMarkers cycle`

E.g. snapshot first
```diff
<<<<<<< Conflict 1 of 1
+++++++ Contents of side #1
HELLO
%%%%%%% Changes from base to side #2
-hello
+hi
>>>>>>> Conflict 1 of 1 ends
```
into snapshot second
```
<<<<<<< Conflict 1 of 1
%%%%%%% Changes from base to side #1
-hello
+HELLO
+++++++ Contents of side #2
hi
>>>>>>> Conflict 1 of 1 ends
```
into snapshot all
```
<<<<<<< Conflict 1 of 1
+++++++ Contents of side #1
HELLO
------- Contents of base
hello
+++++++ Contents of side #2
hi
>>>>>>> Conflict 1 of 1 ends
```
and then back to snapshot first.

### Not yet implemented

* Documentation.

## Flashy screenshots or recordings?
TBD, maybe.

## Example config
For the documented default config, have a look inside `init.lua`.

### Lazy
Example configuration
```
{
  'algmyr/vcmarkers.nvim',
  config = function()
    require('vcmarkers').setup {}

    local function map(mode, lhs, rhs, desc, opts)
      local options = { noremap = true, silent = true, desc = desc }
      if opts then options = vim.tbl_extend('force', options, opts) end
      vim.keymap.set(mode, lhs, rhs, options)
    end

    map('n', ']m', function() require('vcmarkers').actions.next_marker(0, vim.v.count1) end, 'Go to next marker')
    map('n', '[m', function() require('vcmarkers').actions.prev_marker(0, vim.v.count1) end, 'Go to previous marker')
    map('n', '<space>ms', function() require('vcmarkers').actions.select_section(0) end, 'Select the section under the cursor')
    map('n', '<space>mf', function() require('vcmarkers').fold.toggle() end, 'Fold outside markers')
    map('n', '<space>mc', function() require('vcmarkers').actions.cycle_marker(0) end, 'Cycle marker representations')
  end,
}
```
