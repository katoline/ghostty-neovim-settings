# Neovim設定

LazyVim 用の追加設定です。

## 機能

- モードレス（普通のエディタ風）: 通常のファイルを開く・クリックで移ると、そのまま入力できる（インサート）。`Esc` は補完メニューを閉じる・検索ハイライトを消すだけで、ノーマルモードには戻らない。Vim のコマンドは `Ctrl+O` の後で 1 つだけ実行できる。ヘルプ・ファイル一覧・ダッシュボードなど特殊な画面は従来どおり（`keymaps.lua`）
- マウス操作: クリックで入力位置へ移動、ドラッグ / Shift+矢印で選択してそのまま置き換え、タブ（bufferline）のクリックで切り替え、ウィンドウの境界線をドラッグして大きさ変更（`keymaps.lua` と Neovim の `mouse=a`）
- Cmd ショートカット: Cmd+S 保存、Cmd+Z / Cmd+Shift+Z 元に戻す / やり直す、Cmd+C / Cmd+X / Cmd+V / Cmd+A、Cmd+F ファイル内検索、Cmd+P ファイル名検索（`keymaps.lua`。Ghostty と Neovim 0.10 以降が必要）
- ファイル一覧（Snacks explorer）: クリック 1 回でファイルを開く / フォルダを開閉する。ダブルクリックでの確定は無効。ファイルを開いても一覧は開いたまま（`nvim.lua`）
- ドットファイル・gitignore されたファイルの表示: ファイル一覧・ファイル名検索（Cmd+P / `<leader>ff`）・grep（`<leader>/` / `<leader>sg` / `<leader>sw`）で、`.claude/` のようなドットファイルと `.gitignore` されたファイルも既定で表示する。`.git` の中身は表示しない。ファイル一覧では `H` / `I` で隠しファイル・gitignore 対象の表示を切り替えられる（`nvim.lua`）
- 右側のターミナル: Cmd+J / `<C-/>` で列ごと開閉、Cmd+Shift+J で一番下に追加（`keymaps.lua` と `ghostty/keymaps.ghostty`）
- toggleterm.nvim の導入（`nvim.lua`）
- `<leader>tv`: 右側にターミナルを縦分割で開く（`keymaps.lua`）
- LazyVim 標準のターミナル（`<C-/>`・`<leader>ft`・`<leader>fT`）を、下ではなく右側（画面幅の 40%）に開く（`keymaps.lua`）
- Ghostty の Cmd+J でターミナル、Cmd+B で左側のファイル一覧を開閉する（`keymaps.lua` と `ghostty/keymaps.ghostty`）

Ghostty 以外のターミナルでは Cmd キーが Neovim に届かないため、Cmd ショートカットは使えません。

キーボードショートカット一覧は [KEYMAPS.md](KEYMAPS.md) を参照してください。

## セットアップ

先に `~/.config/nvim` に LazyVim を導入してください。

```bash
cd ghostty-neovim-settings/nvim
chmod +x setup.sh
./setup.sh
```

シンボリックリンクの配置先:
- `nvim.lua` → `~/.config/nvim/lua/plugins/terminal.lua`（リンク先の名前は `terminal.lua` のまま）
- `keymaps.lua` → `~/.config/nvim/lua/config/keymaps.lua`

既存のファイル（シンボリックリンクでないもの）は `.backup.<日時>` に退避されます。

リンク済みのファイルを更新しただけなら、`setup.sh` の再実行は不要です。Neovim を開き直すと反映されます。

## ファイルの役割

- **nvim.lua**: lazy.nvim のプラグイン spec（toggleterm.nvim と、Snacks explorer のクリック操作）
- **keymaps.lua**: 追加のキーマップ（モードレス、Cmd ショートカット、右側ターミナルの開閉・追加）
- **setup.sh**: セットアップスクリプト
- **KEYMAPS.md**: キーボードショートカット一覧
- **tests/**: headless の統合テスト（下記）

## テスト

`tests/` に検証用のスクリプトがあります。モードレス・ファイル一覧・ドットファイルの表示・ターミナルのテストは、このリポジトリの `nvim/keymaps.lua` と `nvim/nvim.lua` を `setup.sh` で `~/.config/nvim` にリンクした状態で、実際の LazyVim 設定を読み込んで動きます（ファイルは一時ディレクトリの中だけを開きます）。

リポジトリのルートで実行します。

```bash
bash tests/run_nvim_modeless_test.sh   # モードレス・Esc・Ctrl+O・Cmd キー
bash tests/run_nvim_explorer_test.sh   # ファイル一覧のクリック
bash tests/run_nvim_hidden_files_test.sh  # ドットファイル・gitignore 対象の表示
bash tests/run_nvim_terminal_test.sh   # 右側ターミナルの開閉・追加
bash tests/check_lua_syntax.sh         # Lua の構文チェック
python3 tests/kitty_super_key_test.py  # super キーが <D-...> として届くかの確認
```

`check_lua_syntax.sh` と `kitty_super_key_test.py` は、上記のリンクされた設定を読みません（構文と kitty キーボードプロトコルの確認のみ）。`.harness/verify.json` に、Ghostty の設定検証を含む同じ検証コマンドをまとめてあります。
