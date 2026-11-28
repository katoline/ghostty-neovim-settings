#!/bin/bash

# Snacks のファイル一覧・ファイル名検索・grep が、ドットファイル（.claude/ など）と
# .gitignore されたファイルを表示し、.git の中身は表示しないことの headless テストを実行する。
# ユーザーの実際の LazyVim 設定（~/.config/nvim）を読み込み、
# テスト用の一時ディレクトリ（git リポジトリ）の中だけで動く。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/.claude" "$TMP_DIR/sub"
printf 'needle\n' >"$TMP_DIR/a.txt"
printf 'needle\n' >"$TMP_DIR/.hidden.txt"
printf 'needle\n' >"$TMP_DIR/ignored.txt"
printf 'needle\n' >"$TMP_DIR/.claude/settings.json"
printf 'needle\n' >"$TMP_DIR/sub/b.txt"
printf 'ignored.txt\n' >"$TMP_DIR/.gitignore"
git -C "$TMP_DIR" init -q

cd "$TMP_DIR"
NVIM_HIDDEN_TEST="$ROOT_DIR/tests/nvim_hidden_files_test.lua" \
	NVIM_HIDDEN_CWD="$TMP_DIR" \
	nvim --headless -i NONE -n \
	--cmd "luafile $ROOT_DIR/tests/clipboard_dummy.lua" \
	-c "lua vim.defer_fn(function() dofile(vim.env.NVIM_HIDDEN_TEST) end, 300)"
