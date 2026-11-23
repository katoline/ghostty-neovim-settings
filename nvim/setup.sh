#!/bin/bash

# Neovim設定ファイルのセットアップスクリプト
# このスクリプトは、nvim/ の設定ファイルを LazyVim の設定ディレクトリに
# シンボリックリンクで配置します
#   nvim.lua    -> ~/.config/nvim/lua/plugins/terminal.lua
#   keymaps.lua -> ~/.config/nvim/lua/config/keymaps.lua

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_DIR="$HOME/.config/nvim"

echo "Neovim設定ファイルのセットアップを開始します..."

# LazyVim が未導入なら案内して終了
if [ ! -d "$NVIM_DIR" ]; then
  echo "$NVIM_DIR が見つかりません。"
  echo "先に LazyVim を導入してください: https://www.lazyvim.org/installation"
  exit 1
fi

# link_file <ソース> <リンク先>
link_file() {
  local src="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  # 既存のファイルをバックアップ（シンボリックリンクでない場合）
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "既存のファイルをバックアップ: $target"
    mv "$target" "${target}.backup.$(date +%Y%m%d_%H%M%S)"
  fi

  # 既存のシンボリックリンクは張り替える
  if [ -L "$target" ]; then
    rm "$target"
  fi

  ln -s "$src" "$target"
  echo "  ✓ $target"
}

echo "シンボリックリンクを作成中..."
link_file "$SCRIPT_DIR/nvim.lua" "$NVIM_DIR/lua/plugins/terminal.lua"
link_file "$SCRIPT_DIR/keymaps.lua" "$NVIM_DIR/lua/config/keymaps.lua"

echo ""
echo "セットアップが完了しました！"
echo ""
echo "設定ファイルの場所:"
echo "  ソース: $SCRIPT_DIR"
echo "  リンク先: $NVIM_DIR"
echo ""
echo "Neovim を起動すると toggleterm.nvim が自動でインストールされます。"
echo ""
