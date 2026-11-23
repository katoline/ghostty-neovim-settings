# Neovim キーボードショートカット一覧

LazyVim（extras なし）で使えるキーボードショートカットの早見表です。

## 記法

| 表記 | 意味 |
| --- | --- |
| `<leader>` | Space キー（`<leader>ff` は Space を押してから `f` `f`） |
| `<localleader>` | `\` キー |
| `<C-x>` | Ctrl + x |
| `<S-x>` | Shift + x |
| `<M-x>` / `<A-x>` | Option（Alt）+ x |
| `<CR>` | Enter |
| `<Esc>` | Esc |
| `<Tab>` | Tab |

- 起動は `nvim`。`nvim .` でカレントディレクトリを開きます（`neovim` ではなく `nvim`）。
- 迷ったら Space を押して少し待つと、which-key が続きのキー候補を表示します。
- `<leader>sk` でキーマップを検索できます。
- モード欄：n = ノーマル、i = インサート、v = ビジュアル、o = オペレータ待ち、c = コマンドライン、t = ターミナル。

## よく使うもの

普段の作業はほぼこの節だけで足ります。

### 画面の開閉

| キー | 説明 |
| --- | --- |
| Cmd+J（または `<C-/>`） | 右側のターミナルを開く / 閉じる（ターミナルの中で押しても閉じる） |
| Cmd+B（または `<leader>e` = Space → e） | 左側のファイル一覧（エクスプローラー）を開く / 閉じる（入力中・ターミナルの中で押しても効く） |
| `<C-h>` / `<C-l>` | 左 / 右のウィンドウへ移動（ファイル一覧・エディタ・ターミナルの間を行き来） |
| Cmd+T | Ghostty の新しいタブを開く（Neovim を開いたままでも使える。Ghostty 側の操作） |

### ファイル一覧（エクスプローラー）の中で

| キー | 説明 |
| --- | --- |
| `j` / `k`（または ↓ / ↑） | 下 / 上へ移動 |
| `<CR>`（Enter）または `l` | ファイルを開く / フォルダを開く |
| `h` | フォルダを閉じる |
| `a` | ファイルを新規作成（名前の末尾を `/` にするとフォルダ） |
| `r` / `d` | 名前を変更 / 削除 |
| `H` | 隠しファイルの表示を切り替え |
| `?` | ファイル一覧で使えるキーの一覧を表示 |

### カーソル移動

| キー | 説明 |
| --- | --- |
| 矢印キー（← ↓ ↑ →）または `h` `j` `k` `l` | 左 下 上 右（どちらでも同じ） |
| `w` / `b` | 次 / 前の単語へ |
| `0` / `$` | 行頭 / 行末へ |
| `gg` / `G` | ファイルの先頭 / 末尾へ |

### 入力・修正

起動直後は「ノーマルモード」で、文字は打てません。`i` を押すと入力でき、`Esc` で戻ります。

| キー | 説明 |
| --- | --- |
| `i` | 入力開始（カーソルの前から） |
| `o` | 下に新しい行を作って入力開始 |
| `Esc` | 入力をやめてノーマルモードに戻る（迷ったらまず Esc） |
| `x` | 1 文字削除 |
| `dd` | 1 行削除 |
| `u` / `<C-r>` | 元に戻す / やり直す |
| `yy` / `p` | 1 行コピー / 貼り付け |

### 保存・終了

| キー | 説明 |
| --- | --- |
| `<C-s>`（Ctrl+s） | 保存（入力中でも使える） |
| `:w` + Enter | 保存 |
| `:q` + Enter | 閉じる |
| `:wq` + Enter | 保存して閉じる |
| `:q!` + Enter | 保存せずに閉じる |
| `<leader>qq`（Space → q → q） | Neovim をすべて終了 |

### 探す

| キー | 説明 |
| --- | --- |
| `<leader><space>`（Space → Space） | ファイル名で探して開く |
| `<leader>/`（Space → /） | ファイルの中身を文字列で探す |
| `/語` + Enter、`n` / `N` | 今のファイル内を検索、次 / 前の結果へ |
| `<S-h>` / `<S-l>`（Shift+h / Shift+l） | 開いているファイル（タブ）を前 / 次へ切り替え |

## Vim の基本操作

Vim 標準の操作です（LazyVim のキーマップ取得結果には出てきません）。起動直後は「ノーマルモード」で、文字入力はできません。`i` を押すと入力できます。

### モードの切り替え

| キー | 説明 |
| --- | --- |
| `i` / `a` | カーソルの前 / 後ろから入力開始（インサートモード） |
| `o` / `O` | 下 / 上に新しい行を作って入力開始 |
| `Esc` | ノーマルモードに戻る（迷ったらまず Esc） |
| `v` / `V` / `<C-v>` | 文字 / 行 / 矩形のビジュアル選択 |
| `:` | コマンドライン（`:w` など） |

### 移動

| キー | 説明 |
| --- | --- |
| `h` `j` `k` `l` | 左 下 上 右 |
| `w` / `b` / `e` | 次の単語の頭 / 前の単語の頭 / 単語の末尾 |
| `0` / `^` / `$` | 行頭 / 行の最初の文字 / 行末 |
| `gg` / `G` | ファイルの先頭 / 末尾 |
| `<C-d>` / `<C-u>` | 半画面下 / 上へスクロール |

### 編集

| キー | 説明 |
| --- | --- |
| `x` | カーソル位置の 1 文字を削除 |
| `dd` / `yy` | 行を削除（切り取り）/ コピー |
| `p` / `P` | カーソルの後ろ / 前に貼り付け |
| `u` / `<C-r>` | 元に戻す / やり直す |
| `.` | 直前の変更を繰り返す |
| `ciw` | カーソルの単語を消して入力開始 |
| `dw` / `D` | 単語を削除 / 行末まで削除 |
| `>>` / `<<` | インデントを増やす / 減らす |

### 検索

| キー | 説明 |
| --- | --- |
| `/語` + `<CR>` | 下方向に検索 |
| `n` / `N` | 次 / 前の検索結果 |
| `*` | カーソルの単語を検索 |

### 保存・終了

| コマンド | 説明 |
| --- | --- |
| `:w` | 保存 |
| `:q` | 終了 |
| `:wq` | 保存して終了 |
| `:q!` | 保存せずに強制終了 |

## ファイル・検索

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader><space>` / `<leader>ff` | n | ファイル検索（ルートディレクトリ） |
| `<leader>fF` | n | ファイル検索（カレントディレクトリ） |
| `<leader>fg` | n | ファイル検索（git 管理ファイル） |
| `<leader>fr` | n | 最近開いたファイル |
| `<leader>fR` | n | 最近開いたファイル（カレントディレクトリ） |
| `<leader>fn` | n | 新規ファイル |
| `<leader>fc` | n | 設定ファイルを探す |
| `<leader>fp` | n | プロジェクト一覧 |
| Cmd+B / `<leader>e` / `<leader>fe` | n | エクスプローラー（ルートディレクトリ）を開閉。Cmd+B は i, t モードでも効く |
| `<leader>E` / `<leader>fE` | n | エクスプローラー（カレントディレクトリ） |
| `<leader>/` / `<leader>sg` | n | Grep（ルートディレクトリ） |
| `<leader>sG` | n | Grep（カレントディレクトリ） |
| `<leader>sw` | n, v | 選択範囲 / カーソルの単語を grep（ルートディレクトリ） |
| `<leader>sW` | n, v | 選択範囲 / カーソルの単語を grep（カレントディレクトリ） |
| `<leader>sB` | n | 開いているバッファ内を grep |
| `<leader>sb` | n | バッファ内の行を検索 |
| `<leader>sr` | n, v | 検索と置換 |
| `<leader>sR` | n | 直前の検索を再開 |
| `<leader>s/` | n | 検索履歴 |
| `<leader>sc` / `<leader>:` | n | コマンド履歴 |
| `<leader>sC` | n | コマンド一覧 |
| `<leader>sh` | n | ヘルプページ |
| `<leader>sM` | n | man ページ |
| `<leader>sk` | n | キーマップ |
| `<leader>s"` | n | レジスタ |
| `<leader>sm` | n | マーク |
| `<leader>sj` | n | ジャンプリスト |
| `<leader>sa` | n | autocmd 一覧 |
| `<leader>sH` | n | ハイライトグループ |
| `<leader>si` | n | アイコン |
| `<leader>sp` | n | プラグイン定義を検索 |
| `<leader>su` | n | Undotree（変更履歴ツリー） |
| `<leader>sl` | n | Location List |
| `<leader>sq` | n | Quickfix List |
| `<leader>st` / `<leader>sT` | n | Todo コメント一覧 / Todo・Fix・Fixme のみ |
| `<leader>.` | n | スクラッチバッファの切り替え |
| `<leader>S` | n | スクラッチバッファを選択 |
| `[t` / `]t` | n | 前 / 次の Todo コメント |
| `n` / `N` | n, v, x, o | 次 / 前の検索結果 |
| `<Esc>` | n, i, s, v | 検索ハイライトを消す |

## バッファ

| キー | モード | 説明 |
| --- | --- | --- |
| `<S-h>` / `[b` | n | 前のバッファ |
| `<S-l>` / `]b` | n | 次のバッファ |
| `[B` / `]B` | n | バッファを前 / 次へ移動（並べ替え） |
| `<leader>bb` / `` <leader>` `` | n | 直前のバッファに切り替え |
| `<leader>,` / `<leader>fb` | n | バッファ一覧 |
| `<leader>fB` | n | バッファ一覧（すべて） |
| `<leader>bd` | n | バッファを閉じる |
| `<leader>bD` | n | バッファとウィンドウを閉じる |
| `<leader>bo` | n | 他のバッファをすべて閉じる |
| `<leader>bl` / `<leader>br` | n | 左 / 右のバッファをすべて閉じる |
| `<leader>bp` | n | ピン留めの切り替え |
| `<leader>bP` | n | ピン留めしていないバッファを閉じる |

## ウィンドウ

| キー | モード | 説明 |
| --- | --- | --- |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | n | 左 / 下 / 上 / 右のウィンドウへ移動 |
| `<leader>-` | n | 下に分割 |
| `<leader>\|` | n | 右に分割 |
| `<leader>wd` | n | ウィンドウを閉じる |
| `<leader>wm` / `<leader>uZ` | n | ウィンドウのズーム切り替え |
| `<C-Up>` / `<C-Down>` | n | ウィンドウの高さを増やす / 減らす |
| `<C-Right>` / `<C-Left>` | n | ウィンドウの幅を増やす / 減らす |
| `<C-w>` + Space | n | ウィンドウ操作のハイドラモード（which-key） |

## タブ

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader><Tab><Tab>` | n | 新しいタブ |
| `<leader><Tab>]` / `<leader><Tab>[` | n | 次 / 前のタブ |
| `<leader><Tab>f` / `<leader><Tab>l` | n | 最初 / 最後のタブ |
| `<leader><Tab>d` | n | タブを閉じる |
| `<leader><Tab>o` | n | 他のタブをすべて閉じる |

## コード・LSP

LSP（言語サーバー）が接続されたバッファでのみ有効なものを含みます。

### バッファごと（LSP 接続時のみ）

| キー | モード | 説明 |
| --- | --- | --- |
| `gd` | n | 定義へ移動 |
| `gr` | n | 参照一覧 |
| `gI` | n | 実装へ移動 |
| `gy` | n | 型定義へ移動 |
| `K` | n | ホバー（ドキュメント表示） |
| `gK` | n | シグネチャヘルプ |
| `<C-k>` | i | シグネチャヘルプ |
| `<leader>ca` | n, v | コードアクション |
| `<leader>cA` | n | ソースアクション |
| `<leader>cr` | n | リネーム（シンボル名の一括変更） |
| `<leader>cR` | n | ファイル名のリネーム |
| `<leader>cc` / `<leader>cC` | n | Codelens を実行 / 更新 |
| `<leader>cl` | n | LSP 情報 |
| `]]` / `[[` | n | 同じシンボルの次 / 前の出現位置へ移動 |
| `<M-n>` / `<M-p>` | n | 同上（Option 版） |

### グローバル

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader>cf` | n, v | フォーマット |
| `<leader>cF` | n, v | 埋め込み言語のフォーマット |
| `<leader>cd` | n | カーソル行の診断を表示 |
| `<leader>cm` | n | Mason（LSP やツールの管理）を開く |
| `<leader>cs` | n | シンボル一覧（Trouble） |
| `<leader>cS` | n | LSP の参照・定義など（Trouble） |
| `gra` | n, v, x | コードアクション（Neovim 組み込み） |
| `grn` | n | リネーム（Neovim 組み込み） |
| `grr` | n | 参照一覧（Neovim 組み込み） |
| `gri` | n | 実装（Neovim 組み込み） |
| `grt` | n | 型定義（Neovim 組み込み） |
| `gO` | n | ドキュメントのシンボル一覧（Neovim 組み込み） |
| `K` | n | Keywordprg（キーワードのヘルプ） |
| `<leader>ud` | n | 診断表示の切り替え |
| `<leader>uh` | n | インレイヒントの切り替え |

## 診断・Trouble

| キー | モード | 説明 |
| --- | --- | --- |
| `]d` / `[d` | n | 次 / 前の診断 |
| `]D` / `[D` | n | 現在のバッファの最後 / 最初の診断 |
| `]e` / `[e` | n | 次 / 前のエラー |
| `]w` / `[w` | n | 次 / 前の警告 |
| `<C-w>d` | n | カーソル位置の診断を表示 |
| `<leader>cd` | n | カーソル行の診断 |
| `<leader>xx` | n | 診断一覧（Trouble） |
| `<leader>xX` | n | 現在のバッファの診断（Trouble） |
| `<leader>xl` | n | Location List |
| `<leader>xL` | n | Location List（Trouble） |
| `<leader>xq` | n | Quickfix List |
| `<leader>xQ` | n | Quickfix List（Trouble） |
| `<leader>xt` / `<leader>xT` | n | Todo（Trouble）/ Todo・Fix・Fixme のみ（Trouble） |
| `[q` / `]q` | n | 前 / 次の Trouble・Quickfix 項目 |
| `<leader>sd` | n | 診断（検索ピッカー） |
| `<leader>sD` | n | 現在のバッファの診断（検索ピッカー） |

## Git

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader>gs` | n | Git ステータス |
| `<leader>gd` | n | Git Diff（hunk 単位） |
| `<leader>gD` | n | Git Diff（origin との差分） |
| `<leader>gl` | n | Git ログ |
| `<leader>gL` | n | Git ログ（カレントディレクトリ） |
| `<leader>gf` | n | 現在のファイルの履歴 |
| `<leader>gb` | n | 現在行の blame |
| `<leader>gS` | n | Git Stash |
| `<leader>gB` | n, v, x | ブラウザで開く（GitHub など） |
| `<leader>gY` | n, v, x | ブラウザ用 URL をコピー |
| `<leader>gi` / `<leader>gI` | n | GitHub Issues（open / すべて） |
| `<leader>gp` / `<leader>gP` | n | GitHub Pull Requests（open / すべて） |

### gitsigns（Git 管理下のファイルのみ・バッファごと）

| キー | モード | 説明 |
| --- | --- | --- |
| `]h` / `[h` | n | 次 / 前の hunk（差分ブロック） |
| `]H` / `[H` | n | 最後 / 最初の hunk |
| `<leader>ghs` | n, x | hunk をステージ |
| `<leader>ghr` | n, x | hunk をリセット |
| `<leader>ghS` | n | バッファ全体をステージ |
| `<leader>ghR` | n | バッファ全体をリセット |
| `<leader>ghu` | n | hunk のステージを取り消し |
| `<leader>ghp` | n | hunk をインラインでプレビュー |
| `<leader>ghb` | n | 現在行の blame（詳細） |
| `<leader>ghB` | n | バッファ全体の blame |
| `<leader>ghd` | n | Diff This |
| `<leader>ghD` | n | Diff This ~（直前コミットとの差分） |
| `ih` | o, x | hunk をテキストオブジェクトとして選択 |

注：`<leader>gg` / `<leader>gG`（lazygit を開く）は、`lazygit` コマンドが入っているときだけ有効になります。現在は未インストールのため使えません。

## UI の切り替え（`<leader>u*`）

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader>us` | n | スペルチェック |
| `<leader>uw` | n | 折り返し表示 |
| `<leader>uL` | n | 相対行番号 |
| `<leader>ul` | n | 行番号 |
| `<leader>ud` | n | 診断表示 |
| `<leader>uc` | n | Conceal レベル |
| `<leader>uA` | n | タブライン |
| `<leader>uT` | n | Treesitter ハイライト |
| `<leader>ub` | n | ダーク / ライト背景 |
| `<leader>uh` | n | インレイヒント |
| `<leader>ug` | n | インデントガイド |
| `<leader>ua` | n | アニメーション |
| `<leader>uS` | n | スムーズスクロール |
| `<leader>uD` | n | 非アクティブ部分の暗転（Dimming） |
| `<leader>uf` / `<leader>uF` | n | 自動フォーマット（グローバル / バッファ） |
| `<leader>up` | n | Mini Pairs（括弧の自動補完） |
| `<leader>uz` | n | Zen モード |
| `<leader>uZ` | n | ズームモード |
| `<leader>uC` | n | カラースキーム選択 |
| `<leader>ui` / `<leader>uI` | n | カーソル位置の情報 / Treesitter ツリーを確認 |
| `<leader>un` | n | 通知をすべて閉じる |
| `<leader>ur` | n | 再描画 / 検索ハイライト消去 / Diff 更新 |

## ターミナル

| キー | モード | 説明 |
| --- | --- | --- |
| `<C-/>` | n, t | 右側にターミナルを開閉（ルートディレクトリ） |
| Cmd+J | n, t | 右側にターミナルを開閉（`<C-/>` と同じ。Ghostty で設定） |
| `<leader>ft` | n | 右側にターミナルを開閉（ルートディレクトリ） |
| `<leader>fT` | n | 右側にターミナルを開閉（カレントディレクトリ） |
| `<leader>tv` | n | 右側にターミナルを縦分割で開く（toggleterm、カスタム設定） |

`<C-/>` `<leader>ft` `<leader>fT` は LazyVim 標準では画面の下に開きますが、`nvim/keymaps.lua` で右側（画面幅の 40%）に開くよう変更しています。

Cmd+J は Ghostty の `ghostty/keymaps.ghostty` で Ctrl+/ と同じ制御文字（`<C-_>`）を送るよう設定したものです。Cmd 付きのキーは Neovim に直接届かないため、この形にしています。Ghostty 以外のターミナルでは使えません。

Cmd+B も同じ仕組みで、Ghostty が Ctrl+^（`<C-^>`）を送り、`nvim/keymaps.lua` がそれを「ファイル一覧を開閉」に割り当てています。このため Vim 標準の `<C-^>`（直前のファイルに切り替え）は使えません。同じことは `<leader>bb` でできます。

ターミナル内で入力モードから抜けるには `<C-\><C-n>`（Vim 標準）。

## 編集・テキストオブジェクト

| キー | モード | 説明 |
| --- | --- | --- |
| `s` | n, v, x, o | Flash（ラベルでジャンプ） |
| `S` | n, v, x, o | Flash Treesitter（構文単位で選択） |
| `r` | o | Remote Flash |
| `R` | o, v, x | Treesitter Search |
| `<C-s>` | c | コマンドライン検索での Flash 切り替え |
| `<C-Space>` | n, v, x, o | Treesitter による選択範囲の拡大 |
| `gc` | n, v, x | コメントの切り替え |
| `gcc` | n | 行のコメントを切り替え |
| `gco` / `gcO` | n | 下 / 上にコメント行を追加 |
| `gc` | o | コメントのテキストオブジェクト |
| `<M-j>` / `<M-k>` | n, i, v, x, s | 行を下 / 上へ移動 |
| `[<Space>` / `]<Space>` | n | カーソルの上 / 下に空行を追加 |
| `a` / `i` | o, v, x | Around / Inside のテキストオブジェクト（mini.ai。例：`vaf` `ci"`） |
| `an` / `in` / `al` / `il` | o, v, x | 次 / 最後の対象に対する around / inside |
| `g[` / `g]` | n, o, v, x | 対象の左端 / 右端の around へ移動 |
| `<Tab>` / `<S-Tab>` | i, s, v | スニペット中は次 / 前の入力位置へジャンプ |
| `<C-f>` / `<C-b>` | n, i, v, s | 前方 / 後方へスクロール |
| `gx` | n, v, x | カーソル下のファイルパス / URL を開く |

## セッション・終了

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader>qq` | n | すべて終了 |
| `<leader>qs` | n | セッションを復元 |
| `<leader>qS` | n | セッションを選択 |
| `<leader>ql` | n | 直前のセッションを復元 |
| `<leader>qd` | n | 現在のセッションを保存しない |

## その他

| キー | モード | 説明 |
| --- | --- | --- |
| `<leader>l` | n | Lazy（プラグイン管理） |
| `<leader>L` | n | LazyVim の更新履歴 |
| `<leader>?` | n | バッファのキーマップ一覧（which-key） |
| `<leader>n` | n | 通知履歴 |
| `<leader>snl` | n | Noice：最後のメッセージ |
| `<leader>snh` | n | Noice：履歴 |
| `<leader>sna` | n | Noice：すべて |
| `<leader>snd` | n | Noice：すべて閉じる |
| `<leader>snt` | n | Noice ピッカー |
| `<leader>dpp` | n | プロファイラーの切り替え |
| `<leader>dph` | n | プロファイラーのハイライト切り替え |
| `<leader>dps` | n | プロファイラーのスクラッチバッファ |
| `[a` / `]a` 等 | n | 引数リスト / Quickfix 等の移動（`[q` `]q` は Trouble の項を参照） |

## 省いたもの

- `<Plug>` / `<SNR>` で始まるもの、説明（desc）の無いもの、マウス関連
- Neovim 組み込みの既定マップのうち日常的に使わないもの（`[a` `]L` `[<C-q>` などの引数リスト・Location List 系、`&` `Y` `Q` など）
- mini.pairs のカッコ・クォートの自動補完（`(` `"` など）と `<BS>` `<CR>` の補助マップ
- 矢印キーや `j` `k` の表示行移動、`<C-u>` `<C-w>`（インサートモードの Vim 標準）

## この一覧の作り方

2026-11-23 に、この設定で Neovim を headless 起動し、`nvim_get_keymap` でグローバルなキーマップ（説明付き 357 件）を取り出して整理しました。LSP と gitsigns のバッファごとのキーマップは LazyVim 本体のソースから補っています。「Vim の基本操作」節は Vim 標準の操作を手で選んだものです。

プラグインの更新で内容が変わることがあります。最新の状態は Neovim 内で `<leader>sk`（キーマップ検索）で確認できます。
