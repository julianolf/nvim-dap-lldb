#!/usr/bin/env bash

set -euo pipefail

echo "Preparing directories"

HOME_BIN="$HOME/.local/bin"
mkdir -p "$HOME_BIN"

HOME_DATA="$HOME/.local/share"
mkdir -p "$HOME_DATA"

echo "Installing NeoVim"

NEOVIM_TGZ="$RUNNER_TEMP/neovim.tgz"
curl -sSL "$NEOVIM_URL" -o "$NEOVIM_TGZ"
tar -C "$HOME_DATA" -xzf "$NEOVIM_TGZ"

echo "Installing Selene"

SELENE_ZIP="$RUNNER_TEMP/selene.zip"
curl -sSL "$SELENE_URL" -o "$SELENE_ZIP"
unzip "$SELENE_ZIP" -d "$HOME_BIN"
chmod +x "$HOME_BIN/selene"

echo "Installing StyLua"

STYLUA_ZIP="$RUNNER_TEMP/stylua.zip"
curl -sSL "$STYLUA_URL" -o "$STYLUA_ZIP"
unzip "$STYLUA_ZIP" -d "$HOME_BIN"

echo "Updating PATH"
echo "$HOME_BIN" >>"$GITHUB_PATH"
echo "$HOME_DATA/nvim-linux-x86_64/bin" >>"$GITHUB_PATH"
