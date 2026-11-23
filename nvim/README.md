# Neovim設定

LazyVim 用の追加設定です。

## 機能

- toggleterm.nvim の導入（`nvim.lua`）
- `<leader>tv`: 右側にターミナルを縦分割で開く（`keymaps.lua`）
- LazyVim 標準のターミナル（`<C-/>`・`<leader>ft`・`<leader>fT`）を、下ではなく右側（画面幅の 40%）に開く（`keymaps.lua`）
- Ghostty の Cmd+J でターミナル、Cmd+B で左側のファイル一覧を開閉する（`keymaps.lua` と `ghostty/keymaps.ghostty`）

キーボードショートカット一覧は [KEYMAPS.md](KEYMAPS.md) を参照してください。

## セットアップ

先に `~/.config/nvim` に LazyVim を導入してください。

```bash
cd ghostty-neovim-settings/nvim
chmod +x setup.sh
./setup.sh
```

シンボリックリンクの配置先:
- `nvim.lua` → `~/.config/nvim/lua/plugins/terminal.lua`
- `keymaps.lua` → `~/.config/nvim/lua/config/keymaps.lua`

既存のファイル（シンボリックリンクでないもの）は `.backup.<日時>` に退避されます。

## ファイルの役割

- **nvim.lua**: lazy.nvim のプラグイン spec（toggleterm.nvim）
- **keymaps.lua**: 追加のキーマップ
- **setup.sh**: セットアップスクリプト
- **KEYMAPS.md**: キーボードショートカット一覧
