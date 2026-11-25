#!/bin/bash

# Lua ファイルの構文チェック
# luac が無い環境でも確認できるよう、Neovim の loadfile() でコンパイルする。
# loadfile() はファイルを実行しないので、プラグイン設定を読み込まずに済む。

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

status=0
shopt -s nullglob
for file in nvim/*.lua tests/*.lua; do
	if output=$(nvim --clean --headless -u NONE -i NONE -n \
		-c "lua local chunk, err = loadfile('$file'); if not chunk then vim.api.nvim_err_writeln(err); vim.cmd('cquit 1') end" \
		-c 'qa!' 2>&1); then
		echo "ok: $file"
	else
		echo "構文エラー: $file"
		echo "$output"
		status=1
	fi
done

if [ "$status" -ne 0 ]; then
	echo "Lua の構文エラーがあります"
fi

exit "$status"
