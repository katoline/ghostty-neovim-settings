# Ghostty設定

このディレクトリには、Ghosttyの設定ファイルが機能ごとに分割されています。

## ディレクトリ構成

```
ghostty/
├── config.ghostty        # メイン設定ファイル（各ファイルを読み込む）
├── transparency.ghostty  # 透過設定とショートカット
├── text.ghostty          # 文字の見やすさ（太さ・薄い文字・灰色）
├── keymaps.ghostty       # キーマップ設定
├── env.ghostty           # 環境変数設定
└── setup.sh              # セットアップスクリプト
```

## 機能

### 1. シェル
- シェルは設定せず、既定のログインシェル（zsh）をそのまま使います
- 既存の zsh 設定には触れません

### 2. 透過機能
- 初期状態: 透過（`background-opacity = 0.75`）
- `Ctrl+Shift+T`: 透過と不透明を切り替え
- `background-opacity-cells = true` により、Neovim の背景など背景色を持つセルにも透過がかかります
- 設定ファイル: `transparency.ghostty`

WezTerm 版との違い:
- 起動直後が透過状態です（WezTerm 版は不透明で起動）
- 切り替えは全ウィンドウに同時にかかります（WezTerm 版はウィンドウごと）
- フルスクリーン中は切り替えが効きません

### 3. 文字の見やすさ
- 透過時に文字が薄く見えないよう、少し濃くしています
- `font-thicken = true`（強さ 128）: 文字の線を太めに描きます（macOS のみ）
  - macOS 本体のフォントスムージング設定は Ghostty には効きません。太さはこの設定で調整します
- `faint-opacity = 0.7`: 薄い文字（faint）の不透明度を既定の 0.5 から上げています
- `palette = 8=#8a8a8a`: 灰色（bright black）を既定の `#666666` から明るくしています
- 設定ファイル: `text.ghostty`

### 4. キーマップ
- 追加のキーバインドを設定できます
- `Cmd+J`: Neovim の右側ターミナルを開閉します。Ctrl+/ と同じ制御文字（0x1f）を送り、Neovim 側（`nvim/keymaps.lua`）がそれを受け取ります
  - Ghostty 標準の `Cmd+J`（選択範囲までスクロール）は上書きされます
  - Neovim の外（zsh）で押すと、Ctrl+_ と同じく直前の入力の取り消しになります
- `Cmd+B`: Neovim の左側ファイル一覧（エクスプローラー）を開閉します。Ctrl+^ と同じ制御文字（0x1e）を送り、Neovim 側（`nvim/keymaps.lua`）がそれを受け取ります
  - Ghostty 標準では `Cmd+B` に割り当てはありません。zsh で押しても何も起きません
- 設定ファイル: `keymaps.ghostty`

### 5. 環境変数
- Ghostty 内で使用する環境変数を設定できます
- 設定ファイル: `env.ghostty`

## セットアップ方法

### 初回セットアップ

1. このリポジトリをクローンまたはPullします
2. セットアップスクリプトを実行します：

```bash
cd ghostty-neovim-settings/ghostty
chmod +x setup.sh
./setup.sh
```

または、手動でシンボリックリンクを作成：

```bash
mkdir -p ~/.config/ghostty
cd ~/.config/ghostty
ln -sf /path/to/ghostty-neovim-settings/ghostty/*.ghostty .  # リポジトリを置いた場所に読み替える
```

設定ファイルの配置先は `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/` で、Ghostty は `config.ghostty` を読み込みます。

## 設定のカスタマイズ

### 透過度を変更する

`transparency.ghostty`を編集：

```
background-opacity = 0.75
```

変更後は Ghostty の完全な再起動が必要です。

### キーマップを追加する

`keymaps.ghostty`を編集：

```
keybind = ctrl+shift+n=new_window
```

### 環境変数を追加する

`env.ghostty`を編集：

```
env = CUSTOM_VAR=value
```

`env.ghostty` は公開リポジトリに含まれます。トークンなどの秘密情報やマシン固有の値は、同じディレクトリに `env.local.ghostty` を作ってそちらに書いてください。このファイルは `.gitignore` 済みでコミットされません。`config.ghostty` が `?env.local.ghostty` として読み込むので、ファイルが無くてもエラーになりません。作成後は `./setup.sh` を再実行してリンクを張ります。

## 設定の反映

`background-opacity` を変更した場合は、Ghostty を完全に再起動してください。
それ以外の設定は `Cmd+Shift+,` でリロードできます。

## トラブルシューティング

### 設定が反映されない

1. 設定ファイルが`~/.config/ghostty/`に正しく配置されているか確認：
   ```bash
   ls -la ~/.config/ghostty/
   ```

2. シンボリックリンクが正しく作成されているか確認：
   ```bash
   ls -la ~/.config/ghostty/config.ghostty
   ```

3. 設定を検証：
   ```bash
   ghostty +validate-config
   ```
   `ghostty` コマンドに PATH が通っていない場合は `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config` を使います

4. macOS では `~/Library/Application Support/com.mitchellh.ghostty/config` も読み込まれます。
   そちらに同じ項目を書くと後勝ちで上書きされることがあるため、内容を確認してください

### 透過が動作しない

1. `transparency.ghostty`の設定を確認
2. Ghostty を完全に再起動（`background-opacity` の変更はリロードでは反映されません）
3. フルスクリーン中は `Ctrl+Shift+T` が効きません。フルスクリーンを解除して確認
4. `Ctrl+Shift+T`を押して動作を確認

## ファイルの役割

- **config.ghostty**: メイン設定ファイル。各ファイルを `config-file` で読み込みます
- **transparency.ghostty**: 透過機能とショートカット設定
- **text.ghostty**: 文字の見やすさ（太さ・薄い文字・灰色）
- **keymaps.ghostty**: 追加のキーマップ設定
- **env.ghostty**: 環境変数の設定

各ファイルは独立しており、必要な機能だけを有効にできます。
