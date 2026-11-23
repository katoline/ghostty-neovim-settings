-- 右側にターミナル（縦分割）を開く
vim.keymap.set("n", "<leader>tv", function()
	require("toggleterm").toggle(1, 80, nil, "vertical")
end, { desc = "Toggle Vertical Terminal" })

-- LazyVim 標準のターミナル（Snacks）を、下ではなく右側に開くよう上書きする
-- このファイルは LazyVim の標準キーマップの後に読み込まれるので、同じキーを定義すれば上書きになる
local right = { position = "right", width = 0.4 } -- 画面幅の 40%

local function terminal_root()
	-- Snacks の標準のトグルは「開いた場所のルートディレクトリ」でターミナルを識別するため、
	-- ターミナルやファイル一覧の中で押すとルートの判定が変わり、閉じずに 2 つ目が開いてしまう。
	-- そこで、右側のターミナルが既にあればそれを使う：表示中なら閉じ、隠れていれば表示し直す
	local hidden
	for _, term in ipairs(Snacks.terminal.list()) do
		if term.opts.position == "right" then
			if term:valid() then
				term:hide()
				return
			end
			hidden = hidden or term
		end
	end
	if hidden then
		hidden:show()
		return
	end
	Snacks.terminal(nil, { cwd = LazyVim.root(), win = right })
end

vim.keymap.set({ "n", "t" }, "<C-/>", terminal_root, { desc = "Terminal (Root Dir)" })
-- 端末によっては Ctrl+/ が <C-_> として届くので同じ動作にする
vim.keymap.set({ "n", "t" }, "<C-_>", terminal_root, { desc = "which_key_ignore" })
vim.keymap.set("n", "<leader>ft", terminal_root, { desc = "Terminal (Root Dir)" })
vim.keymap.set("n", "<leader>fT", function()
	Snacks.terminal(nil, { win = right })
end, { desc = "Terminal (cwd)" })

-- Cmd+B で左側のファイル一覧（エクスプローラー）を開閉する
-- Ghostty が Cmd+B で Ctrl+^（0x1e = <C-^>）を送る（ghostty/keymaps.ghostty）ので、それを受け取る。
-- Snacks.explorer は開いていれば閉じる（<leader>e と同じ動作）。
-- Vim 標準の <C-^>（直前のファイルに切り替え）は <leader>bb で代わりに使える。
vim.keymap.set({ "n", "i", "t" }, "<C-^>", function()
	-- 開くときだけ、入力中・ターミナル入力中ならノーマルモードへ戻す。
	-- 閉じるときに戻すと、ターミナルの中で閉じた後に入力できない状態が残る
	if not Snacks.picker.get({ source = "explorer" })[1] then
		vim.cmd.stopinsert()
	end
	Snacks.explorer({ cwd = LazyVim.root() })
end, { desc = "Explorer (Cmd+B)" })
