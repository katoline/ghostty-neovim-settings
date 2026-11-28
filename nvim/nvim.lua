-- lazy.nvim のプラグイン spec
-- ~/.config/nvim/lua/plugins/terminal.lua としてリンクされ、LazyVim が読み込む。
-- Neovim 内ターミナル（toggleterm）と、Snacks のファイル一覧・ピッカーの表示を設定する。
return {
	{
		"akinsho/toggleterm.nvim", -- Neovim 内ターミナルのプラグイン
		version = "*",
		opts = {}, -- 既定の設定を使う
	},
	{
		"folke/snacks.nvim",
		opts = {
			picker = {
				sources = {
					explorer = {
						-- ドットファイル（.claude/ など）と .gitignore されたファイルも表示する。
						-- 隠したいときは、一覧で H（hidden）/ I（ignored）を押して切り替える。
						hidden = true,
						ignored = true,
						-- .git の中身は表示しない（ファイル名検索・grep も .git を除く）
						exclude = { ".git" },
						win = {
							list = {
								keys = {
									-- 既定ではダブルクリック（<2-LeftMouse>）が confirm に割り当てられている。
									-- シングルクリックでも確定するため、残すとフォルダが余分に開閉する。
									["<2-LeftMouse>"] = false,
									-- 左クリック 1 回で、ファイルなら開き、フォルダなら開閉する。
									-- エディタでインサート中にクリックすることもあるので i モードにも割り当てる
									["<LeftRelease>"] = { "explorer_left_click", mode = { "n", "i" } },
								},
							},
						},
						actions = {
							-- snacks の action は function(picker, item) で呼ばれる
							explorer_left_click = function(picker)
								local list = picker.list
								if not list or not list.win or not list.win:valid() then
									return
								end
								-- クリック位置がリスト以外（別ウィンドウでのドラッグ終了など）なら何もしない
								local pos = vim.fn.getmousepos()
								if pos.winid ~= list.win.win then
									return
								end
								-- pos.winrow はウィンドウ内の表示行（1 始まり）なので、
								-- 表示行からアイテム番号に変換して範囲を確認する
								local idx = list:row2idx(pos.winrow)
								if idx < 1 or idx > list:count() then
									return
								end
								-- インサート中のクリックでもキー操作が効くよう、先にノーマルへ戻す。
								-- （stopinsert の反映は次のイベントループだが、確定はそのまま実行できる）
								if vim.fn.mode():sub(1, 1) == "i" then
									vim.cmd.stopinsert()
								end
								-- クリックした行を選択してから確定する（ファイルは開き、フォルダは開閉する）
								list:_move(idx, true, true)
								picker:action("confirm")
							end,
						},
					},
					-- ファイル名検索（Cmd+P・<leader>ff など）と grep（<leader>/・<leader>sg・<leader>sw など）でも、
					-- ドットファイル（.claude/ など）と .gitignore されたファイルを表示する。
					-- .git は Snacks が fd / rg の引数で除外している。
					files = {
						hidden = true,
						ignored = true,
					},
					grep = {
						hidden = true,
						ignored = true,
					},
					grep_word = {
						hidden = true,
						ignored = true,
					},
				},
			},
		},
	},
}
