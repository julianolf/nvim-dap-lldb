#!/usr/bin/env bash

set -euo pipefail

nvim --headless \
	-u NONE -i NONE \
	--cmd "set rtp+=$(pwd)" \
	-c "lua assert(pcall(require, 'dap-lldb'))" \
	-c "qa"

nvim --headless -u NONE -i NONE -c "luafile tests/ui.lua"
