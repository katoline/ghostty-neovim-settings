#!/bin/bash

# Ghostty設定ファイルのセットアップスクリプト
# このスクリプトは、ghostty/ の設定ファイルを
# ${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/ にシンボリックリンクで配置します

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"

echo "Ghostty設定ファイルのセットアップを開始します..."

# 設定ディレクトリが存在しない場合は作成
if [ ! -d "$CONFIG_DIR" ]; then
  echo "ディレクトリを作成: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
fi

# 既存のファイルをバックアップ（シンボリックリンクでない場合）
for file in "$CONFIG_DIR"/*.ghostty; do
  if [ -f "$file" ] && [ ! -L "$file" ]; then
    echo "既存のファイルをバックアップ: $file"
    mv "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
  fi
done

# シンボリックリンクを作成
echo "シンボリックリンクを作成中..."
for file in "$SCRIPT_DIR"/*.ghostty; do
  if [ -f "$file" ]; then
    filename=$(basename "$file")
    target="$CONFIG_DIR/$filename"

    # 既存のシンボリックリンクを削除
    if [ -L "$target" ]; then
      rm "$target"
    fi

    # シンボリックリンクを作成
    ln -sf "$file" "$target"
    echo "  ✓ $filename"
  fi
done

echo ""
echo "セットアップが完了しました！"
echo ""
echo "設定ファイルの場所:"
echo "  ソース: $SCRIPT_DIR"
echo "  リンク先: $CONFIG_DIR"
echo ""
echo "background-opacity の変更は Ghostty の完全な再起動が必要です。"
echo "その他の設定は Cmd+Shift+, でリロードできます。"
echo ""
