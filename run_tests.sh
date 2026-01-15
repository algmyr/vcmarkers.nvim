#!/bin/bash
cd "$(dirname "$0")"
nvim --headless -c "lua require('vcmarkers_tests').run()" -c "q" 2>&1
