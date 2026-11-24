-- 右側にターミナル（縦分割）を開く
vim.keymap.set("n", "<leader>tv", function()
	require("toggleterm").toggle(1, 80, nil, "vertical")
end, { desc = "Toggle Vertical Terminal" })

-- LazyVim 標準のターミナル（Snacks）を、下ではなく右側に開くよう上書きする
-- このファイルは LazyVim の標準キーマップの後に読み込まれるので、同じキーを定義すれば上書きになる
local right = { position = "right", width = 0.4 } -- 画面幅の 40%

-- 右列のターミナルを「作った順」で覚えておく。
-- Snacks.terminal.list() は内部のテーブル（tid がキー）を走査するので順番が保証されない。
-- 上から作った順に積み直せるよう、順番はここで持つ。
local right_terminals = {}

-- 右列のターミナルのうち、プロセスが生きているもの（バッファが有効なもの）を作った順に返す。
-- Snacks.terminal.list() は exit 済みのものも返すので buf_valid で絞る。
local function right_column()
	local live, seen = {}, {}
	for _, term in ipairs(right_terminals) do
		if term:buf_valid() and term.opts.position == "right" then
			live[#live + 1] = term
			seen[term] = true
		end
	end
	-- <leader>fT など、この一覧を通らない経路で開いたものも列の一員として扱う。
	-- 作った順は分からないので、見つけた順に後ろへ足す。
	for _, term in ipairs(Snacks.terminal.list()) do
		if term.opts.position == "right" and not seen[term] then
			live[#live + 1] = term
			seen[term] = true
		end
	end
	right_terminals = live
	return live
end

-- 右列の一番下に新しいターミナルを追加する。
-- Snacks は tid（cmd・cwd・env・count）でターミナルを識別するため、同じ識別子だと
-- 既存のものが返って新しいプロセスが増えない。そこで count をずらして別のターミナルにする。
local right_count = 0
local function new_right_terminal()
	local cwd = LazyVim.root()
	local function exists(count)
		-- create = false なので既存のものがあればそれを返すだけ（新規作成しない）
		return Snacks.terminal.get(nil, { cwd = cwd, count = count, create = false }) ~= nil
	end
	local count = right_count + 1
	while exists(count) do
		count = count + 1
	end
	right_count = count
	local term = Snacks.terminal(nil, { cwd = cwd, count = count, win = right })
	-- 新規作成なので作った順の最後（= 一番下）に足す
	right_terminals[#right_terminals + 1] = term
	return term
end

-- 右列のウィンドウを画面上から順に返す。
-- nvim_tabpage_list_wins() の順はレイアウト順とは限らないので row で並べ直す。
local function column_windows()
	local wins = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local meta = vim.w[win].snacks_win
		if meta and meta.position == "right" then
			wins[#wins + 1] = win
		end
	end
	table.sort(wins, function(a, b)
		return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
	end)
	return wins
end

-- 右列のウィンドウを terms の順（上が先）に並べ直す。
-- Snacks は stack = true のとき「最初に見つかった同じ位置のウィンドウ」の下に
-- 新しいウィンドウを差し込むため、3 つ以上あると上から 2 番目などに入ってしまう。
-- そこで、隣り合う 2 つが逆順なら上のウィンドウを 1 つ下と交換して並べ直す。
local function arrange_right_column(terms)
	local order = {}
	for i, term in ipairs(terms) do
		if term:win_valid() then
			order[term.win] = i
		end
	end
	local wins = column_windows()
	for _ = 1, #wins do
		for j = #wins - 1, 1, -1 do
			local a, b = wins[j], wins[j + 1]
			if order[a] and order[b] and order[a] > order[b] then
				-- CTRL-W x はカレントウィンドウを 1 つ下のウィンドウと交換する
				vim.api.nvim_set_current_win(a)
				vim.cmd("wincmd x")
				wins[j], wins[j + 1] = b, a
			end
		end
	end
end

-- 右列のウィンドウの高さを均等にする。
-- Snacks の equalize() は 3 つ以上だと揃わないことがあるので、
-- 現在の高さの合計を配り直す（合計を変えないのでレイアウトが崩れない）。
local function equalize_right_column(terms)
	local wins, total = {}, 0
	for _, term in ipairs(terms) do
		if term:win_valid() then
			wins[#wins + 1] = term.win
			total = total + vim.api.nvim_win_get_height(term.win)
		end
	end
	if #wins < 2 then
		return
	end
	local base = math.floor(total / #wins)
	local rest = total - base * #wins
	for i, win in ipairs(wins) do
		-- 端数は上から順に配る
		pcall(vim.api.nvim_win_set_height, win, base + (i <= rest and 1 or 0))
	end
end

-- 並び順と高さを整える。
-- Snacks も表示時に高さを均等化するが、それは vim.schedule で後から走るので、
-- こちらも schedule して後に上書きする（並び順はウィンドウができた直後に直せる）。
local function layout_right_column(terms)
	arrange_right_column(terms)
	vim.schedule(function()
		equalize_right_column(terms)
	end)
end

-- 隠れているターミナルを全部表示し直す（作った順 = 上から）。
local function show_right_column(terms)
	for _, term in ipairs(terms) do
		term:show()
	end
	layout_right_column(terms)
end

local function terminal_root()
	-- Snacks の標準のトグルは「開いた場所のルートディレクトリ」でターミナルを識別するため、
	-- ターミナルやファイル一覧の中で押すとルートの判定が変わり、閉じずに 2 つ目が開いてしまう。
	-- そこで右列を丸ごと扱う：表示中のものがあれば全部隠し（プロセスは残す）、
	-- 全部隠れていれば作った順に全部表示し直す。一つも無ければ 1 つ目を作る。
	local terms = right_column()
	local visible = vim.tbl_filter(function(term)
		return term:valid()
	end, terms)
	if #visible > 0 then
		for _, term in ipairs(visible) do
			term:hide()
		end
		return
	end
	if #terms > 0 then
		show_right_column(terms)
		return
	end
	new_right_terminal()
end

-- Cmd+Shift+J: 右列を維持したまま、一番下に新しいターミナルを追加する。
local function terminal_new()
	local terms = right_column()
	-- 隠れているものがあれば先に全部戻す（表示中のものはそのまま）
	for _, term in ipairs(terms) do
		if not term:valid() then
			term:show()
		end
	end
	local term = new_right_terminal()
	layout_right_column(right_column())
	-- 並べ直しでカレントが移っていることがあるので、新しいターミナルに戻して入力できるようにする
	if term:win_valid() then
		vim.api.nvim_set_current_win(term.win)
		if vim.bo[term.buf].buftype == "terminal" then
			vim.cmd.startinsert()
		end
	end
end

-- インサート中（モードレス）でも開閉できるように i も対象にする。
-- ターミナルを開いたときは、フォーカスした時点で startinsert される
-- （このファイルの「モードレス」節の autocmd）。
vim.keymap.set({ "n", "i", "t" }, "<C-/>", terminal_root, { desc = "Terminal (Root Dir)" })
-- 端末によっては Ctrl+/ が <C-_> として届くので同じ動作にする
vim.keymap.set({ "n", "i", "t" }, "<C-_>", terminal_root, { desc = "which_key_ignore" })
vim.keymap.set("n", "<leader>ft", terminal_root, { desc = "Terminal (Root Dir)" })
-- Ghostty の super+shift+j が <D-J> として届く（ghostty/keymaps.ghostty で unbind している）
vim.keymap.set({ "n", "i", "t" }, "<D-J>", terminal_new, { desc = "New Terminal (Cmd+Shift+J)" })
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

-- ===========================================================================
-- モードレス（普通のエディタ風）
-- ===========================================================================
-- 通常のファイルを開いたらインサートモードのまま編集し、<Esc> では抜けない。
-- ノーマルモードは <C-o>（1 回だけ Vim コマンド）などの脱出口として残す。

-- マウスのドラッグと Shift+矢印で選択（セレクトモード）に入る。
-- セレクトモードでは文字を打つと選択範囲が置き換わり、
-- シフトなしの矢印を押すと選択が解除される（keymodel の stopsel）。
vim.opt.selectmode = "mouse,key"
vim.opt.keymodel = "startsel,stopsel"

-- インサートにしてよいバッファかどうか。
-- buftype が空で、書き換え可能・読み取り専用でないものだけを対象にする。
-- ヘルプ（buftype=help）、ダッシュボード / explorer / ピッカー / Lazy / Mason
-- （buftype=nofile, prompt など）はノーマルのままにする。
local function is_editable_buffer(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	local bo = vim.bo[buf]
	return bo.buftype == "" and bo.modifiable and not bo.readonly
end

-- インサートのまま入ってしまうと困るバッファかどうか。
-- 編集できないバッファ（buftype が空でないもの、または書き換え不可・読み取り専用の
-- 普通のファイル）を対象にする。ヘルプ・ファイル一覧（Snacks のリストは buftype=nofile）・
-- ダッシュボード・quickfix などに、エディタ側のインサートが残らないようにするため。
-- ただし自分でインサートを使うものは除外する：
-- ターミナル（buftype=terminal）、プロンプト（buftype=prompt。Snacks の入力欄は
-- filetype=snacks_picker_input / snacks_input で buftype=prompt、vim.ui.input も同じ）、
-- および Snacks の入力欄（古い入力欄は buftype が nofile に書き換わるため filetype でも除外）。
local function should_leave_insert(buf)
	local bo = vim.bo[buf]
	if bo.buftype == "terminal" or bo.buftype == "prompt" then
		return false
	end
	if bo.filetype == "snacks_picker_input" or bo.filetype == "snacks_input" then
		return false
	end
	if bo.buftype ~= "" then
		return true
	end
	return not bo.modifiable or bo.readonly
end

-- autocmd の中から直接 startinsert すると、モードの変更が次のイベントループまで
-- 遅れることがあるため schedule する。その間に別のバッファへ移っていたら何もしない。
local function start_insert(buf)
	vim.schedule(function()
		if vim.api.nvim_get_current_buf() == buf and is_editable_buffer(buf) then
			vim.cmd.startinsert()
		end
	end)
end

-- 特殊バッファに入ったとき、前のバッファのインサートが残っていたらノーマルへ戻す。
-- これも schedule しないと stopinsert が次のイベントループまで反映されない。
local function leave_insert(buf)
	vim.schedule(function()
		if vim.api.nvim_get_current_buf() ~= buf or not should_leave_insert(buf) then
			return
		end
		local m = vim.fn.mode():sub(1, 1)
		if m == "i" or m == "R" then
			vim.cmd.stopinsert()
		end
	end)
end

local function start_terminal_insert(buf)
	vim.schedule(function()
		if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == "terminal" then
			vim.cmd.startinsert()
		end
	end)
end

local modeless = vim.api.nvim_create_augroup("UserModeless", { clear = true })

-- バッファに入る / ウィンドウを移るたびに対象を判定してインサートにする。
-- マウスでクリックしてウィンドウを移ったときも WinEnter で拾える。
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
	group = modeless,
	callback = function(event)
		if vim.bo[event.buf].buftype == "terminal" then
			start_terminal_insert(event.buf)
		elseif should_leave_insert(event.buf) then
			leave_insert(event.buf)
		else
			start_insert(event.buf)
		end
	end,
})

-- このファイルは VeryLazy で読み込まれるため、読み込み時点で既に開いている
-- バッファには上の autocmd が間に合わない。現在のバッファにも一度適用する。
if vim.bo.buftype == "terminal" then
	start_terminal_insert(vim.api.nvim_get_current_buf())
else
	start_insert(vim.api.nvim_get_current_buf())
end

-- インサート中の <Esc> は「ノーマルに戻る」ではなく、
-- 補完メニュー・検索ハイライト・スニペットだけを片付ける。
-- 何もキーを返さないのでインサートのまま、カーソルも動かない。
-- LazyVim 標準の <Esc>（noh + snippet_stop + <esc>）を上書きする。
vim.keymap.set("i", "<Esc>", function()
	vim.cmd("nohlsearch")

	-- blink.cmp の補完メニューが出ていれば閉じる
	pcall(function()
		require("blink.cmp").hide()
	end)

	-- LuaSnip / vim.snippet のスニペットジャンプを止める
	pcall(function()
		LazyVim.cmp.actions.snippet_stop()
	end)
end, { desc = "Close popup / Clear hlsearch (stay in Insert)" })

-- ビジュアル / セレクトからノーマルに戻ったら、通常ファイルならインサートに戻す。
-- <C-o> はインサート -> ノーマル -> インサートと遷移するが、
-- 旧モードが i / niI なのでこの条件には当たらず、1 回だけのコマンドを邪魔しない。
vim.api.nvim_create_autocmd("ModeChanged", {
	group = modeless,
	pattern = "*",
	callback = function()
		local old = vim.v.event.old_mode
		local new = vim.v.event.new_mode
		-- v/V/<C-v> = ビジュアル、s/S/<C-s> = セレクト
		if new == "n" and old:find("^[vVsS\22\19]") then
			start_insert(vim.api.nvim_get_current_buf())
		end
	end,
})

-- 常時インサートだと undo が 1 つの塊になりやすいので区切りを入れる。
-- LazyVim は , . ; に <C-g>u を入れているので、ここでは Space を担当する。
-- <CR> に <C-g>u を付けると mini.pairs の括弧内での改行展開や blink.cmp の
-- 確定を壊す恐れがあるため、<CR> にはマップを置かず autocmd で区切る。
vim.keymap.set("i", "<Space>", "<C-g>u<Space>", { desc = "Undo break" })

-- インサート中に 'undolevels' を同じ値で設定し直すと、そこで undo が区切られる
-- （:h undo-break の let &g:undolevels = &g:undolevels と同じ）。
-- インサートのまま実行でき、<C-g>u のようにキー入力自体を置き換えないので
-- 補完や自動補完のポップアップを壊さない。
local function break_undo()
	vim.o.undolevels = vim.o.undolevels
end

-- 入力が止まったら区切る（1 つの単語を打ち終えた直後など）。
vim.api.nvim_create_autocmd("CursorHoldI", {
	group = modeless,
	callback = break_undo,
})

-- 改行などで行数が変わったら区切る。
-- これがないと、行を跨いで入力した内容が 1 つの undo 塊になってしまう。
local last_line_count = {}
vim.api.nvim_create_autocmd({ "InsertEnter", "TextChangedI" }, {
	group = modeless,
	callback = function(event)
		local count = vim.api.nvim_buf_line_count(event.buf)
		local previous = last_line_count[event.buf]
		last_line_count[event.buf] = count
		if previous and previous ~= count then
			break_undo()
		end
	end,
})
vim.api.nvim_create_autocmd("BufDelete", {
	group = modeless,
	callback = function(event)
		last_line_count[event.buf] = nil
	end,
})

-- ---------------------------------------------------------------------------
-- Cmd ショートカット（Ghostty の super+... が <D-...> として届く）
-- ---------------------------------------------------------------------------
-- Ghostty 側（ghostty/keymaps.ghostty）で super+z / super+shift+z / super+a /
-- super+f を unbind している。これにより Neovim の kitty キーボードプロトコル
-- 対応 TUI では <D-z> などとして受け取れる。

local function save_file()
	if not is_editable_buffer(0) then
		return
	end
	-- 名前の無いバッファで :write するとファイル名を尋ねられるので何もしない
	if vim.api.nvim_buf_get_name(0) == "" then
		return
	end
	vim.cmd("silent! write")
end

-- <D-s>: 保存。インサートを維持するため <Esc> を送らない。
vim.keymap.set({ "n", "i", "x", "s" }, "<D-s>", save_file, { desc = "Save File (Cmd+S)" })
-- LazyVim 標準の <C-s>（:w のあと <Esc>）は保存後にノーマルへ落ちるので、同じ動作で上書きする
vim.keymap.set({ "n", "i", "x", "s" }, "<C-s>", save_file, { desc = "Save File" })

-- 選択範囲の種類（v / V / <C-v>）を返す。選択中でなければ nil。
local function selection_type()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "s" then
		return "v"
	elseif mode == "V" or mode == "S" then
		return "V"
	elseif mode == "\22" or mode == "\19" then
		return "\22"
	end
	return nil
end

-- <D-z> / <D-Z>: 元に戻す / やり直す。インサートのまま実行する。
-- Neovim に super+shift+z が届くと <D-Z> として扱われる（シフトは大文字に
-- 吸収され、<D-S-z> と <D-Z> は Neovim では同じキーになる）。
-- 実際の届き方は tests/kitty_super_key_test.py で確認している。
-- 選択中（ビジュアル / セレクト）のときは、先に選択を解除してから undo / redo する。
-- 選択を残したまま undo すると選択範囲が置き換わったり、セレクトのままになって
-- しまうため。解除すると ModeChanged でインサートに戻る（最終的にはインサート）。
local function undo_or_redo(cmd)
	if selection_type() ~= nil then
		-- "x" を付けて、後ろの undo / redo より先にノーマルへ移す
		local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
		vim.api.nvim_feedkeys(keys, "nx", false)
	end
	pcall(cmd)
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-z>", function()
	undo_or_redo(vim.cmd.undo)
end, { desc = "Undo (Cmd+Z)" })
vim.keymap.set({ "n", "i", "x", "s" }, "<D-Z>", function()
	undo_or_redo(vim.cmd.redo)
end, { desc = "Redo (Cmd+Shift+Z)" })

-- <D-c>: 選択範囲を + レジスタ（システムクリップボード）へコピーする。
-- SSH などで 'clipboard' が空でも OSC52 でコピーできるよう、"+ を明示する。
-- 選択が無いときは何もしない（カーソル行を勝手にコピーしない）。
local function copy_selection()
	local seltype = selection_type()
	if not seltype then
		return
	end
	local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = seltype })
	if ok and region then
		pcall(vim.fn.setreg, "+", region, seltype)
	end
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-c>", copy_selection, { desc = "Copy Selection (Cmd+C)" })

-- <D-x>: 選択範囲を + レジスタへ切り取る。選択が無いときは何もしない。
-- セレクトモードのままキーを送ると `"` が文字として入力され、選択範囲を
-- 置き換えてしまう。そこでセレクトのときは先に <C-g> でビジュアルへ切り替え、
-- そのあとブラックホールレジスタで削除する。
-- 選択が解除された後は ModeChanged でインサートに戻る。
local function cut_selection()
	local seltype = selection_type()
	if not seltype then
		return
	end
	local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = seltype })
	if ok and region then
		pcall(vim.fn.setreg, "+", region, seltype)
	end
	local mode = vim.fn.mode()
	local select_mode = mode == "s" or mode == "S" or mode == "\19"
	local keys = select_mode and '<C-g>"_d' or '"_d'
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-x>", cut_selection, { desc = "Cut Selection (Cmd+X)" })

-- <D-a>: 全選択。ビジュアル（行単位）にしてからセレクトモードへ移す。
-- セレクトモードなので、続けて文字を打つと全体が置き換わり、<D-c> でコピーできる。
-- stopinsert や normal! を関数の中で呼ぶと、インサートの解除が次のイベント
-- ループまで遅れて処理がずれることがある。そのため、キー入力として
-- 「インサートを抜ける -> 全行ビジュアル -> セレクトへ切り替え」を送る。
-- （セレクトモードへは <C-g> で入る。:startselect のような Ex コマンドは無い）
local function select_all()
	local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>ggVG<C-g>", true, false, true)
	vim.api.nvim_feedkeys(keys, "n", false)
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-a>", select_all, { desc = "Select All (Cmd+A)" })

-- <D-f>: ファイル内検索（現在のバッファの行を Snacks ピッカーで探す）。
-- ピッカーを開く前にインサートを抜ける（ピッカー自身の入力を壊さないため）。
local function pick_lines()
	vim.cmd.stopinsert()
	Snacks.picker.lines({ buf = 0 })
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-f>", pick_lines, { desc = "Find in File (Cmd+F)" })

-- <D-p>: ファイル名検索（LazyVim の <leader><space> と同じ、ルートディレクトリ）。
local function pick_files()
	vim.cmd.stopinsert()
	Snacks.picker.files({ cwd = LazyVim.root() })
end
vim.keymap.set({ "n", "i", "x", "s" }, "<D-p>", pick_files, { desc = "Find Files (Cmd+P)" })
-- ターミナル（t モード）には <D-...> を定義しない。
-- ターミナル内の Cmd+C / Cmd+V はシェル側に任せる。
