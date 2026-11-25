#!/bin/bash

# モードレス設定の headless 統合テストを実行する
# ユーザーの実際の LazyVim 設定（~/.config/nvim）を読み込み、
# テスト用の一時ファイルだけを編集する。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'hello\nworld\n' >"$TMP_DIR/startup.txt"

cd "$ROOT_DIR"

# -i NONE: shada を読み書きしない
# -n: スワップファイルを作らない
# --cmd: LazyVim が clipboard を使う前にテスト用の provider を設定する
nvim --headless -i NONE -n \
	--cmd "luafile tests/clipboard_dummy.lua" \
	-c "lua vim.defer_fn(function() dofile('tests/nvim_modeless_test.lua') end, 300)" \
	"$TMP_DIR/startup.txt"
