#!/usr/bin/env bash

set -euo pipefail

nvim --headless \
	-u NONE \
	--cmd "set rtp+=$(pwd)" \
	-c "lua assert(pcall(require, 'dap-lldb'))" \
	-c "qa"
