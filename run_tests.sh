#!/bin/bash
cd "$(dirname "$0")"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --filter | -f)
    export TEST_FILTER="$2"
    shift 2
    ;;
  --filter=*)
    export TEST_FILTER="${1#*=}"
    shift
    ;;
  *)
    shift
    ;;
  esac
done

nvim --headless -c "lua require('vcmarkers_tests').run()" -c "q" 2>&1
