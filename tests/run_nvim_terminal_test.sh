#!/bin/bash

# 右側ターミナル（Cmd+J / Cmd+Shift+J）の headless 統合テストを実行する
# ユーザーの実際の LazyVim 設定（~/.config/nvim）を読み込み、
# テスト用の一時ディレクトリの中だけでファイルを開く。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'hello\nworld\n' >"$TMP_DIR/startup.txt"

# 実際のクリップボードを汚さないよう、テスト専用の provider を使う
# （tests/clipboard_dummy.lua を --cmd で読み込んでいる）。
cd "$TMP_DIR"
NVIM_TERMINAL_TEST="$ROOT_DIR/tests/nvim_terminal_test.lua" \
	NVIM_TERMINAL_CWD="$TMP_DIR" \
	nvim --headless -i NONE -n \
	--cmd "luafile $ROOT_DIR/tests/clipboard_dummy.lua" \
	-c "lua vim.defer_fn(function() dofile(vim.env.NVIM_TERMINAL_TEST) end, 300)" \
	"$TMP_DIR/startup.txt"
