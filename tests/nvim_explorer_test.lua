-- Snacks explorer の左クリック設定の headless 統合テスト
--
-- tests/run_nvim_explorer_test.sh から、ユーザーの実際の LazyVim 設定
-- （~/.config/nvim）を読み込んだ nvim で実行する。
-- カレントディレクトリ（NVIM_EXPLORER_CWD）はテスト用の一時ディレクトリで、
-- そこに a.txt と sub/b.txt がある。
--
-- headless では UIEnter が来ないため VeryLazy が自動では発火しない。
-- テスト側で 1 回だけ発火させ、マウスイベントと検証を非同期のステップに分ける
-- （nvim_input_mouse のイベントはコールバックの外に出てから処理されるため）。

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

local cwd = vim.env.NVIM_EXPLORER_CWD
if not cwd or cwd == "" then
	vim.api.nvim_err_writeln("NVIM_EXPLORER_CWD がありません")
	vim.cmd("cquit 1")
end
cwd = vim.fn.fnamemodify(cwd, ":p"):gsub("/$", "")
-- macOS の /var は /private/var へのリンクなので、実パスに揃えて比較する
cwd = (vim.uv or vim.loop).fs_realpath(cwd) or cwd

-- テスト中に undo ファイル・スワップファイルを作らない
vim.opt.undofile = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- headless では VimEnter がまだのことがあるので待つ
vim.wait(10000, function()
	return vim.v.vim_did_enter == 1
end, 20)

-- VeryLazy を 1 回だけ発火させる。これで keymaps.lua（モードレス設定）が読み込まれる。
if not vim.g.did_very_lazy then
	pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "VeryLazy", modeline = false })
end

-- keymaps.lua の読み込み完了を待つ
local loaded = vim.wait(30000, function()
	return vim.fn.maparg("<D-s>", "i") ~= ""
end, 100)
check("VeryLazy 後にモードレス設定が読み込まれる", loaded)

-- explorer を一時ディレクトリで開き、リストが描画されるまで待つ
Snacks.explorer({ cwd = cwd })

local function get_picker()
	return Snacks.picker.get({ source = "explorer" })[1]
end

local function list_lines()
	local picker = get_picker()
	if not picker or not picker.list or not picker.list.win or not picker.list.win:valid() then
		return {}
	end
	return vim.api.nvim_buf_get_lines(picker.list.win.buf, 0, -1, false)
end

-- リストのウィンドウは開閉のたびに変わることがあるので、そのつど取り直す
local function current_list_win()
	local picker = get_picker()
	if picker and picker.list and picker.list.win and picker.list.win:valid() then
		return picker.list.win.win
	end
end

local function find_line(needle)
	for i, line in ipairs(list_lines()) do
		if line:find(needle, 1, true) then
			return i
		end
	end
end

local rendered = vim.wait(30000, function()
	local picker = get_picker()
	if not picker or not picker.list or not picker.list.win or not picker.list.win:valid() then
		return false
	end
	if picker.list:count() < 2 then
		return false
	end
	return find_line("a.txt") ~= nil and find_line("sub") ~= nil
end, 100)
check("explorer のリストに sub と a.txt が描画される", rendered)

local picker = get_picker()
local list_win = picker and picker.list and picker.list.win and picker.list.win:valid() and picker.list.win.win or nil
local list_buf = picker and picker.list and picker.list.win and picker.list.win:valid() and picker.list.win.buf or nil
local initial_count = picker and picker.list:count() or 0
-- a.txt を開いたときのエディタ側のウィンドウ（インサート中のクリックのテストで使う）
local editor_win

-- クリックした行の画面座標を求めて、実際にマウスイベントを送る。
-- 画面行（0 始まり）= ウィンドウの画面上の位置 + (バッファ行 - topline)
local function click(needle)
	local win = current_list_win() or list_win
	if not win or not vim.api.nvim_win_is_valid(win) then
		error("explorer のリストウィンドウがありません")
	end
	local line = find_line(needle)
	if not line then
		error("リストに " .. needle .. " の行が見つかりません")
	end
	local pos = vim.api.nvim_win_get_position(win)
	local topline = vim.fn.line("w0", win)
	local height = vim.api.nvim_win_get_height(win)
	if line - topline >= height then
		error(("%s の行がリストの表示範囲外です (line=%d topline=%d height=%d)"):format(needle, line, topline, height))
	end
	local row = pos[1] + (line - topline)
	local col = pos[2] + 3 -- 行番号・アイコンを避けて、テキストの上をクリックする
	vim.api.nvim_input_mouse("left", "press", "", 0, row, col)
	vim.api.nvim_input_mouse("left", "release", "", 0, row, col)
end

local steps = {}
local function step(name, fn)
	steps[#steps + 1] = { name = name, fn = fn }
end

-- ---------------------------------------------------------------------------
-- リストのキーマップ
-- ---------------------------------------------------------------------------
step("list keys", function()
	check("explorer のリストウィンドウがある", list_win ~= nil and vim.api.nvim_win_is_valid(list_win))
	check("explorer のリストバッファがある", list_buf ~= nil and vim.api.nvim_buf_is_valid(list_buf))
	if not (list_buf and vim.api.nvim_buf_is_valid(list_buf)) then
		return
	end

	local maps = vim.api.nvim_buf_get_keymap(list_buf, "n")
	local left_release, double_click
	for _, map in ipairs(maps) do
		if map.lhs == "<LeftRelease>" then
			left_release = map
		elseif map.lhs == "<2-LeftMouse>" then
			double_click = map
		end
	end
	check("<LeftRelease> に左クリックの処理が割り当てられている", left_release ~= nil)
	check("<2-LeftMouse> が confirm に割り当てられていない", double_click == nil, double_click and vim.inspect(double_click) or nil)
end)

-- ---------------------------------------------------------------------------
-- フォルダ: 1 回目のクリックで開き、2 回目で閉じる
-- ---------------------------------------------------------------------------
step("click sub", function()
	check("クリック前に sub の行がある", find_line("sub") ~= nil)
	check("クリック前に b.txt は一覧に無い", find_line("b.txt") == nil)
	click("sub")
end)

step("sub opened", function()
	local opened = vim.wait(10000, function()
		return find_line("b.txt") ~= nil
	end, 50)
	check("sub を 1 回クリックすると開いて b.txt が出る", opened, vim.inspect(list_lines()))
	eq("開いた後のアイテム数", get_picker() and get_picker().list:count() or -1, initial_count + 1)
end)

step("click sub again", function()
	click("sub")
end)

step("sub closed", function()
	local closed = vim.wait(10000, function()
		return find_line("b.txt") == nil
	end, 50)
	check("sub をもう 1 回クリックすると閉じる", closed, vim.inspect(list_lines()))
	eq("閉じた後のアイテム数", get_picker() and get_picker().list:count() or -1, initial_count)
end)

-- ---------------------------------------------------------------------------
-- ファイル: 1 回目のクリックでエディタ側に開き、インサートモードになる
-- ---------------------------------------------------------------------------
step("click a.txt", function()
	check("クリック前に a.txt の行がある", find_line("a.txt") ~= nil)
	click("a.txt")
end)

step("a.txt opened", function()
	local opened = vim.wait(10000, function()
		return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") == "a.txt"
	end, 50)
	check("a.txt を 1 回クリックするとエディタ側で開く", opened, "buf=" .. vim.api.nvim_buf_get_name(0))
	if opened then
		local opened_path = (vim.uv or vim.loop).fs_realpath(vim.api.nvim_buf_get_name(0)) or vim.api.nvim_buf_get_name(0)
		eq("開いたファイルのパス", opened_path, cwd .. "/a.txt")
		check("カレントウィンドウが explorer のリストではない", vim.api.nvim_get_current_win() ~= list_win)
		eq("開いたファイルの buftype", vim.bo.buftype, "")
	end
	local insert = vim.wait(5000, function()
		return vim.fn.mode(1):sub(1, 1) == "i"
	end, 50)
	check("開いたファイルはインサートモードになる", insert, "mode=" .. vim.fn.mode(1))
	-- インサート中のクリックを試すため、エディタ側のウィンドウを覚えておく
	if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") == "a.txt" then
		editor_win = vim.api.nvim_get_current_win()
	end
end)

-- ---------------------------------------------------------------------------
-- エディタでインサート中にフォルダ行をクリックしても開閉でき、リストはノーマルになる
-- ---------------------------------------------------------------------------
step("click sub while insert", function()
	check("エディタ側のウィンドウを覚えている", editor_win ~= nil and vim.api.nvim_win_is_valid(editor_win))
	check("フォルダのクリック前にインサート", vim.fn.mode(1):sub(1, 1) == "i", "mode=" .. vim.fn.mode(1))
	check("クリック前に b.txt は一覧に無い", find_line("b.txt") == nil, vim.inspect(list_lines()))
	click("sub")
end)

step("sub opened while insert", function()
	local opened = vim.wait(10000, function()
		return find_line("b.txt") ~= nil
	end, 50)
	check("インサート中でもフォルダ行のクリックで開く", opened, vim.inspect(list_lines()))
	local normal = vim.wait(5000, function()
		return vim.fn.mode(1) == "n"
	end, 20)
	check("フォルダを開いた後のリストはノーマル", normal, "mode=" .. vim.fn.mode(1))
	check(
		"フォルダを開いた後はリストのウィンドウがカレント",
		vim.api.nvim_get_current_win() == current_list_win(),
		"current=" .. vim.api.nvim_get_current_win()
	)
end)

-- ---------------------------------------------------------------------------
-- エディタでインサート中にファイル行をクリックしても開ける
-- ---------------------------------------------------------------------------
step("back to editor", function()
	check("エディタ側のウィンドウが残っている", editor_win ~= nil and vim.api.nvim_win_is_valid(editor_win))
	vim.api.nvim_set_current_win(editor_win)
end)

step("click b.txt while insert", function()
	local insert = vim.wait(5000, function()
		return vim.fn.mode(1):sub(1, 1) == "i"
	end, 20)
	check("エディタに戻るとインサート", insert, "mode=" .. vim.fn.mode(1))
	click("b.txt")
end)

step("b.txt opened while insert", function()
	local opened = vim.wait(10000, function()
		return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") == "b.txt"
	end, 50)
	check("インサート中でもファイル行のクリックで開く", opened, "buf=" .. vim.api.nvim_buf_get_name(0))
	if opened then
		local opened_path = (vim.uv or vim.loop).fs_realpath(vim.api.nvim_buf_get_name(0)) or vim.api.nvim_buf_get_name(0)
		eq("開いたファイルのパス (b.txt)", opened_path, cwd .. "/sub/b.txt")
		check("カレントウィンドウが explorer のリストではない (b.txt)", vim.api.nvim_get_current_win() ~= current_list_win())
	end
	local insert = vim.wait(5000, function()
		return vim.fn.mode(1):sub(1, 1) == "i"
	end, 50)
	check("インサート中に開いたファイルもインサートになる", insert, "mode=" .. vim.fn.mode(1))
end)

-- ---------------------------------------------------------------------------
-- 実行
-- ---------------------------------------------------------------------------
local function finish()
	local text = table.concat(results, "\n")
	print(text)
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
	-- マウスイベント・モード変更・再描画が次のステップまでに反映されるよう待つ
	vim.defer_fn(run_next, 300)
end

if not rendered or not loaded then
	finish()
else
	vim.defer_fn(run_next, 300)
end
