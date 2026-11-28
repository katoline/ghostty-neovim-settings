#!/bin/bash

# gitsigns と bufferline の見た目設定（変更行のサイン・行番号・未保存マーク）の
# headless テストを実行する。
# ユーザーの実際の LazyVim 設定（~/.config/nvim）を読み込み、
# テスト用の一時ディレクトリの中だけで動く（ファイルは開かない）。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 実際のクリップボードを汚さないよう、テスト専用の provider を使う
# （tests/clipboard_dummy.lua を --cmd で読み込んでいる）。
cd "$TMP_DIR"
NVIM_DIFF_TEST="$ROOT_DIR/tests/nvim_diff_status_test.lua" \
	nvim --headless -i NONE -n \
	--cmd "luafile $ROOT_DIR/tests/clipboard_dummy.lua" \
	-c "lua vim.defer_fn(function() dofile(vim.env.NVIM_DIFF_TEST) end, 300)"
