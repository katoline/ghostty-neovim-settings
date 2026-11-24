-- 右側ターミナル（Cmd+J / Cmd+Shift+J）の headless 統合テスト
--
-- tests/run_nvim_terminal_test.sh から、ユーザーの実際の LazyVim 設定
-- （~/.config/nvim）を読み込んだ nvim で実行する。
-- カレントディレクトリ（NVIM_TERMINAL_CWD）はテスト用の一時ディレクトリで、
-- そこに startup.txt を開いて開始する。
--
-- headless では UIEnter が来ないため VeryLazy が自動では発火しない。
-- テスト側で 1 回だけ発火させ、キー入力と検証を非同期のステップに分ける
-- （feedkeys で積んだキー・startinsert・ウィンドウの開閉は
-- コマンドの区切りで反映されるため）。

local results = {}
local failures = 0

local function record(ok, name, detail)
	if ok then
		results[#results + 1] = "ok - " .. name
	else
		failures = failures + 1
		results[#results + 1] = "not ok - " .. name .. (detail and ("\n  " .. detail) or "")
	end
end

local function check(name, cond, detail)
	record(cond and true or false, name, detail)
end

local function eq(name, actual, expected)
	local same = vim.deep_equal(actual, expected)
	record(same, name, same and nil or ("expected: " .. vim.inspect(expected) .. "\n  actual:   " .. vim.inspect(actual)))
end

local function mode()
	return vim.fn.mode(1)
end

local function is_insert()
	return mode():sub(1, 1) == "i"
end

local function is_terminal_insert()
	return mode():sub(1, 1) == "t"
end

local function feed(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

local cwd = vim.env.NVIM_TERMINAL_CWD
if not cwd or cwd == "" then
	vim.api.nvim_err_writeln("NVIM_TERMINAL_CWD がありません")
	vim.cmd("cquit 1")
end
cwd = vim.fn.fnamemodify(cwd, ":p"):gsub("/$", "")

-- テスト中に undo ファイル・スワップファイルを作らない
vim.opt.undofile = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- シェルを軽くする（ターミナルを開くたびに 1 プロセス起動するため）
vim.o.shell = "/bin/sh"

-- headless では VimEnter がまだのことがあるので待つ
vim.wait(10000, function()
	return vim.v.vim_did_enter == 1
end, 20)

-- VeryLazy を 1 回だけ発火させる。これで keymaps.lua（ターミナル設定）が読み込まれる。
if not vim.g.did_very_lazy then
	pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "VeryLazy", modeline = false })
end

-- keymaps.lua の読み込み完了を待つ
local loaded = vim.wait(30000, function()
	return vim.fn.maparg("<D-J>", "n") ~= ""
end, 100)
check("VeryLazy 後にターミナルのキーマップが読み込まれる", loaded)

local editor_buf = vim.api.nvim_get_current_buf()
-- エディタ側のウィンドウも覚えておく（位置の比較に使う）
local editor_win = vim.api.nvim_get_current_win()

-- ターミナルのウィンドウを画面の上から（同じ列なら row の小さい順）に返す
local function term_windows()
	local wins = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "terminal" then
			local pos = vim.api.nvim_win_get_position(win)
			wins[#wins + 1] = {
				win = win,
				buf = buf,
				row = pos[1],
				col = pos[2],
				width = vim.api.nvim_win_get_width(win),
				height = vim.api.nvim_win_get_height(win),
			}
		end
	end
	table.sort(wins, function(a, b)
		if a.col ~= b.col then
			return a.col < b.col
		end
		return a.row < b.row
	end)
	return wins
end

local function bufs(wins)
	local ret = {}
	for i, w in ipairs(wins) do
		ret[i] = w.buf
	end
	return ret
end

local function wait_terms(count)
	return vim.wait(15000, function()
		return #term_windows() == count
	end, 50)
end

local function wait_mode(pred)
	return vim.wait(10000, function()
		return pred(mode())
	end, 50)
end

local steps = {}
local function step(name, fn)
	steps[#steps + 1] = { name = name, fn = fn }
end

-- 最初の 2 つ（作成順）のバッファを覚えておく
local first_bufs = {}

-- ---------------------------------------------------------------------------
-- キーマップの存在
-- ---------------------------------------------------------------------------
step("keymaps exist", function()
	for _, m in ipairs({ "n", "i", "t" }) do
		local map = vim.fn.maparg("<D-J>", m)
		check(("<D-J> が %s モードにある"):format(m), map ~= "", "maparg=" .. map)
	end
	eq("<D-J> を押す前はターミナルのウィンドウが無い", #term_windows(), 0)
end)

-- ---------------------------------------------------------------------------
-- ターミナルが無い状態で <D-J> -> 右側に 1 つ目
-- ---------------------------------------------------------------------------
step("press D-J (first)", function()
	feed("<D-J>")
end)

step("first terminal", function()
	local opened = wait_terms(1)
	check("ターミナルが 1 つ開く", opened, vim.inspect(term_windows()))
	local wins = term_windows()
	if #wins == 0 then
		return
	end
	local term = wins[1]
	first_bufs[1] = term.buf
	local editor_col = vim.api.nvim_win_is_valid(editor_win) and vim.api.nvim_win_get_position(editor_win)[2] or -1
	check("ターミナルはエディタより右にある", term.col > editor_col, ("term.col=%d editor.col=%d"):format(term.col, editor_col))
	local expected_width = math.floor(vim.o.columns * 0.4)
	check(
		"ターミナルの幅は画面の 40%",
		math.abs(term.width - expected_width) <= 2,
		("width=%d expected=%d"):format(term.width, expected_width)
	)
	eq("ターミナルの buftype", vim.bo[term.buf].buftype, "terminal")
	eq("カレントウィンドウはターミナル", vim.api.nvim_get_current_win(), term.win)
	local in_term = wait_mode(is_terminal_insert)
	check("ターミナルにフォーカスして入力できる (t モード)", in_term, "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- もう一度 <D-J> -> 同じ列の下に 2 つ目
-- ---------------------------------------------------------------------------
step("press D-J (second)", function()
	feed("<D-J>")
end)

step("second terminal", function()
	local opened = wait_terms(2)
	check("ターミナルが 2 つになる", opened, vim.inspect(term_windows()))
	local wins = term_windows()
	if #wins < 2 then
		return
	end
	first_bufs[2] = wins[2].buf
	eq("2 つは同じ列にある", { wins[1].col, wins[2].col }, { wins[1].col, wins[1].col })
	eq("2 つの幅が同じ", wins[2].width, wins[1].width)
	check("2 つ目は 1 つ目より下にある", wins[2].row > wins[1].row, ("row1=%d row2=%d"):format(wins[1].row, wins[2].row))
	check("2 つは別のバッファ", wins[1].buf ~= wins[2].buf)
	eq("カレントウィンドウは 2 つ目", vim.api.nvim_get_current_win(), wins[2].win)
	local in_term = wait_mode(is_terminal_insert)
	check("2 つ目にフォーカスして入力できる (t モード)", in_term, "mode=" .. mode())
	eq("上から作成順に並ぶ", bufs(wins), { first_bufs[1], first_bufs[2] })
end)

-- ---------------------------------------------------------------------------
-- <C-_> で全部隠す（プロセスは残る）
-- ---------------------------------------------------------------------------
step("press C-_ (hide all)", function()
	feed("<C-_>")
end)

step("all hidden", function()
	local hidden = wait_terms(0)
	check("表示中のターミナルが 0 になる", hidden, vim.inspect(term_windows()))
	local back = wait_mode(is_insert)
	check("カレントはエディタに戻ってインサートになる", back, "mode=" .. mode())
	eq("カレントバッファはエディタ", vim.api.nvim_get_current_buf(), editor_buf)
	for i, buf in ipairs(first_bufs) do
		check(
			("%d つ目のバッファは残っている（プロセス維持）"):format(i),
			vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal"
		)
	end
end)

-- ---------------------------------------------------------------------------
-- <C-_> で 2 つとも表示し直す（上から同じ順番）
-- ---------------------------------------------------------------------------
step("press C-_ (show all)", function()
	feed("<C-_>")
end)

step("all shown", function()
	local shown = wait_terms(2)
	check("隠す前の 2 つが再表示される", shown, vim.inspect(term_windows()))
	local wins = term_windows()
	if #wins < 2 then
		return
	end
	eq("再表示しても上から同じバッファ順", bufs(wins), { first_bufs[1], first_bufs[2] })
	eq("再表示しても同じ列", { wins[1].col, wins[2].col }, { wins[1].col, wins[1].col })
	local in_term = wait_mode(is_terminal_insert)
	check("再表示後はターミナルに入力できる (t モード)", in_term, "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- 隠した状態で <D-J> -> 既存 2 つが戻り、3 つ目が一番下に追加される
-- ---------------------------------------------------------------------------
step("hide then press D-J", function()
	feed("<C-_>")
end)

step("hidden again", function()
	local hidden = wait_terms(0)
	check("<D-J> の前に全部隠れる", hidden, vim.inspect(term_windows()))
	feed("<D-J>")
end)

step("third terminal", function()
	local opened = wait_terms(3)
	check("隠れていた 2 つが戻り、3 つ目が追加される", opened, vim.inspect(term_windows()))
	local wins = term_windows()
	if #wins < 3 then
		return
	end
	eq("3 つとも同じ列", { wins[1].col, wins[2].col, wins[3].col }, { wins[1].col, wins[1].col, wins[1].col })
	eq("3 つの幅が同じ", { wins[2].width, wins[3].width }, { wins[1].width, wins[1].width })
	eq("上から作成順に並ぶ", { wins[1].buf, wins[2].buf }, { first_bufs[1], first_bufs[2] })
	check("3 つ目は既存と別のバッファ", wins[3].buf ~= first_bufs[1] and wins[3].buf ~= first_bufs[2])
	check("3 つ目は一番下", wins[3].row > wins[2].row, ("row2=%d row3=%d"):format(wins[2].row, wins[3].row))
	local heights = { wins[1].height, wins[2].height, wins[3].height }
	local min_h, max_h = math.min(unpack(heights)), math.max(unpack(heights))
	check("積んだターミナルの高さはほぼ均等", max_h - min_h <= 2, vim.inspect(heights))
	eq("カレントウィンドウは 3 つ目", vim.api.nvim_get_current_win(), wins[3].win)
	local in_term = wait_mode(is_terminal_insert)
	check("3 つ目にフォーカスして入力できる (t モード)", in_term, "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- ターミナルの中（t モード）で <C-_> を押しても全部閉じる
-- ---------------------------------------------------------------------------
step("press C-_ inside terminal", function()
	check("ターミナルの中で押す前は t モード", is_terminal_insert(), "mode=" .. mode())
	feed("<C-_>")
end)

step("hidden from terminal", function()
	local hidden = wait_terms(0)
	check("ターミナルの中で <C-_> を押すと全部隠れる", hidden, vim.inspect(term_windows()))
	local back = wait_mode(is_insert)
	check("そのあとエディタに戻ってインサートになる", back, "mode=" .. mode())
	eq("カレントバッファはエディタ", vim.api.nvim_get_current_buf(), editor_buf)
end)

-- ---------------------------------------------------------------------------
-- 3 つを隠してから <C-_> -> 3 つとも作った順で戻る
-- ---------------------------------------------------------------------------
step("press C-_ (show three)", function()
	feed("<C-_>")
end)

step("three shown in order", function()
	local shown = wait_terms(3)
	check("3 つとも再表示される", shown, vim.inspect(term_windows()))
	local wins = term_windows()
	if #wins < 3 then
		return
	end
	eq("再表示しても上から作成順", bufs(wins), { first_bufs[1], first_bufs[2], wins[3].buf })
	check("3 つ目は一番下のまま", wins[3].row > wins[2].row, ("row2=%d row3=%d"):format(wins[2].row, wins[3].row))
end)

-- ---------------------------------------------------------------------------
-- 実行
-- ---------------------------------------------------------------------------
-- headless では Snacks のターミナルが残っていると :qall! / :cquit が終わらない
-- （Snacks の ExitPre でウィンドウを閉じる処理が止まる。--clean の :terminal では起きない）。
-- 終了の前にターミナルのバッファを消しておく。
local function wipe_terminals()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
end

local function finish()
	local text = table.concat(results, "\n")
	print(text)
	wipe_terminals()
	if failures > 0 then
		vim.api.nvim_err_writeln(("%d 件のテストが失敗しました"):format(failures))
		vim.cmd("cquit 1")
	else
		print(("すべてのテストが成功しました (%d 件)"):format(#results))
		vim.cmd("qall!")
	end
end

-- 何かの拍子に終わらない場合でも、必ず有限時間で失敗させる
vim.defer_fn(function()
	vim.api.nvim_err_writeln("テストがタイムアウトしました")
	wipe_terminals()
	vim.cmd("cquit 1")
end, 120000)

local function run_next()
	local s = table.remove(steps, 1)
	if not s then
		finish()
		return
	end
	local ok, err = pcall(s.fn)
	if not ok then
		failures = failures + 1
		results[#results + 1] = "not ok - " .. s.name .. "\n  " .. tostring(err)
	end
	-- ウィンドウの開閉・モード変更・再描画が次のステップまでに反映されるよう待つ
	vim.defer_fn(run_next, 300)
end

if not loaded then
	finish()
else
	vim.defer_fn(run_next, 300)
end
