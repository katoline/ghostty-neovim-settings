#!/bin/bash

# Snacks explorer の左クリック設定の headless 統合テストを実行する
# ユーザーの実際の LazyVim 設定（~/.config/nvim）を読み込み、
# テスト用の一時ディレクトリの中だけでファイルを開く。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/sub"
printf 'a\n' >"$TMP_DIR/a.txt"
printf 'b\n' >"$TMP_DIR/sub/b.txt"

# 実際のクリップボードを汚さないよう、テスト専用の provider を使う
# （tests/clipboard_dummy.lua を --cmd で読み込んでいる）。
cd "$TMP_DIR"
NVIM_EXPLORER_TEST="$ROOT_DIR/tests/nvim_explorer_test.lua" \
	NVIM_EXPLORER_CWD="$TMP_DIR" \
	nvim --headless -i NONE -n \
	--cmd "luafile $ROOT_DIR/tests/clipboard_dummy.lua" \
	-c "lua vim.defer_fn(function() dofile(vim.env.NVIM_EXPLORER_TEST) end, 300)"
