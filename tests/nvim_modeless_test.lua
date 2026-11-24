-- モードレス設定の headless 統合テスト
--
-- tests/run_nvim_modeless_test.sh から、ユーザーの実際の LazyVim 設定
-- （~/.config/nvim）を読み込んだ nvim で実行する。
--
-- headless では UIEnter が来ないため VeryLazy が自動では発火しない。
-- テスト側で 1 回だけ発火させ、そのあとキー入力を非同期のステップに分けて
-- 検証する（startinsert やモード変更はコマンドの区切りで反映されるため）。

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

local function feed(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

-- 実際のクリップボードを汚さないよう、テスト専用の provider を使う
-- （tests/clipboard_dummy.lua を --cmd で読み込んでいる）。
local function clipboard(reg)
	local c = _G.__test_clipboard and _G.__test_clipboard[reg or "+"]
	return c and c.lines or nil
end

local initial_file = vim.fn.expand("%:p")
local tmpdir = vim.fn.fnamemodify(initial_file, ":h")

-- テスト中に undo ファイル・スワップファイルを作らない
vim.opt.undofile = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- headless では VimEnter がまだのことがあるので待つ
vim.wait(10000, function()
	return vim.v.vim_did_enter == 1
end, 20)

-- VeryLazy を 1 回だけ発火させる。これで keymaps.lua が読み込まれる。
if not vim.g.did_very_lazy then
	pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "VeryLazy", modeline = false })
end

-- keymaps.lua の読み込み完了を待つ
local loaded = vim.wait(30000, function()
	return vim.fn.maparg("<D-s>", "i") ~= ""
end, 100)
check("VeryLazy 後に <D-s> が読み込まれる", loaded)

-- keymaps.lua は VeryLazy で読み込まれ、インサートへの移行は schedule される。
-- 読み込み直後はまだノーマルのことがあるので、移行が終わるのを待ってから始める。
-- （待ってもインサートにならなければ、最初のステップが失敗する）
vim.wait(5000, function()
	return vim.fn.maparg("<D-s>", "i") ~= "" and vim.fn.mode(1):sub(1, 1) == "i"
end, 20)

local steps = {}
local function step(name, fn)
	steps[#steps + 1] = { name = name, fn = fn }
end

-- ---------------------------------------------------------------------------
-- 起動直後（既にファイルを開いている状態で keymaps.lua が読まれた場合）
-- ---------------------------------------------------------------------------
step("startup buffer", function()
	eq("起動時のバッファは通常ファイル", vim.bo.buftype, "")
	eq("起動時のファイル名", vim.api.nvim_buf_get_name(0), initial_file)
	check("起動直後からインサート", is_insert(), "mode=" .. mode())
	eq("selectmode", vim.o.selectmode, "mouse,key")
	eq("keymodel", vim.o.keymodel, "startsel,stopsel")
end)

-- ---------------------------------------------------------------------------
-- キーマップの存在
-- ---------------------------------------------------------------------------
step("keymaps exist", function()
	for _, key in ipairs({ "<D-s>", "<D-c>", "<D-x>", "<D-a>", "<D-f>", "<D-p>" }) do
		for _, m in ipairs({ "n", "i", "x", "s" }) do
			local map = vim.fn.maparg(key, m)
			check(("<%s> が %s モードにある"):format(key, m), map ~= "", "maparg=" .. map)
		end
	end
	for _, key in ipairs({ "<D-z>", "<D-Z>", "<D-S-z>" }) do
		-- 選択中（ビジュアル x / セレクト s）でも効くこと
		for _, m in ipairs({ "n", "i", "x", "s" }) do
			local map = vim.fn.maparg(key, m)
			check(("<%s> が %s モードにある"):format(key, m), map ~= "", "maparg=" .. map)
		end
	end

	check("<C-/> がインサートにもある", vim.fn.maparg("<C-/>", "i") ~= "")
	check("<C-_> がインサートにもある", vim.fn.maparg("<C-_>", "i") ~= "")

	-- ターミナル（t モード）には Cmd 系を定義しない
	for _, key in ipairs({ "<D-s>", "<D-c>", "<D-x>", "<D-z>", "<D-a>", "<D-f>", "<D-p>" }) do
		check(("<%s> は t モードに無い"):format(key), vim.fn.maparg(key, "t") == "")
	end
end)

-- ---------------------------------------------------------------------------
-- インサート中の <Esc> は抜けない・カーソルが動かない
-- ---------------------------------------------------------------------------
local esc_line
local esc_col
step("type in insert", function()
	check("入力前にインサート", is_insert(), "mode=" .. mode())
	feed("abc")
end)

step("after typing", function()
	esc_line = vim.fn.getline(1)
	esc_col = vim.fn.col(".")
	eq("インサートで入力できる", esc_line, "abchello")
	check("入力後もインサート", is_insert(), "mode=" .. mode())
	feed("<Esc>")
end)

step("after Esc", function()
	check("<Esc> 後もインサート", is_insert(), "mode=" .. mode())
	eq("<Esc> でカーソルが動かない", vim.fn.col("."), esc_col)
	eq("<Esc> で本文が変わらない", vim.fn.getline(1), esc_line)
end)

-- ---------------------------------------------------------------------------
-- ビジュアル / セレクトから抜けたらインサートに戻る
-- ---------------------------------------------------------------------------
step("leave insert for visual", function()
	vim.cmd.stopinsert()
end)

step("visual", function()
	check("stopinsert でノーマル", mode() == "n", "mode=" .. mode())
	feed("v")
end)

step("visual -> insert", function()
	eq("v でビジュアル", mode(), "v")
	feed("<Esc>")
end)

step("visual escape", function()
	check("ビジュアルから抜けたらインサート", is_insert(), "mode=" .. mode())
	vim.cmd.stopinsert()
end)

step("select", function()
	check("stopinsert でノーマル (select)", mode() == "n", "mode=" .. mode())
	feed("gh")
end)

step("select -> insert", function()
	eq("gh でセレクト", mode(), "s")
	feed("<Esc>")
end)

step("select escape", function()
	check("セレクトから抜けたらインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- <C-o> で 1 回だけノーマルのコマンドを実行できる
-- ---------------------------------------------------------------------------
local co_lines
step("C-o command", function()
	check("<C-o> の前にインサート", is_insert(), "mode=" .. mode())
	co_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	feed("<C-o>dd")
end)

step("C-o result", function()
	check("<C-o> の後もインサート", is_insert(), "mode=" .. mode())
	local expected = { unpack(co_lines, 2) }
	eq("<C-o>dd が 1 回だけ実行される", vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
end)

-- ---------------------------------------------------------------------------
-- undo の区切り / Cmd+Z / Cmd+Shift+Z
-- ---------------------------------------------------------------------------
step("reset buffer", function()
	-- インサートのままバッファを空にする。
	-- stopinsert と startinsert を同じコールバックで呼ぶと startinsert が
	-- 反映されない（Neovim の挙動）ため、stopinsert はしない。
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("type two words", function()
	check("undo テストの前にインサート", is_insert(), "mode=" .. mode())
	feed("foo<Space>bar")
end)

step("undo one word", function()
	eq("2 単語を入力できる", vim.fn.getline(1), "foo bar")
	check("入力後もインサート", is_insert(), "mode=" .. mode())
	feed("<D-z>")
end)

step("after D-z", function()
	eq("<D-z> で 1 単語ぶんだけ戻る", vim.fn.getline(1), "foo")
	check("<D-z> の後もインサート", is_insert(), "mode=" .. mode())
	feed("<D-Z>")
end)

step("after D-Z", function()
	eq("<D-Z> でやり直せる", vim.fn.getline(1), "foo bar")
	check("<D-Z> の後もインサート", is_insert(), "mode=" .. mode())
	feed("<D-z>")
end)

step("after D-z again", function()
	eq("やり直し前にもう一度戻せる", vim.fn.getline(1), "foo")
	feed("<D-S-z>")
end)

step("after D-S-z", function()
	eq("<D-S-z> でもやり直せる", vim.fn.getline(1), "foo bar")
	check("<D-S-z> の後もインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- Cmd+S
-- ---------------------------------------------------------------------------
step("save", function()
	check("<D-s> の前にインサート", is_insert(), "mode=" .. mode())
	feed("<D-s>")
end)

step("save result", function()
	eq("<D-s> でディスクに書かれる", vim.fn.readfile(initial_file), { "foo bar" })
	check("<D-s> の後もインサート", is_insert(), "mode=" .. mode())
	-- redo 後のカーソル位置に依存しないよう、行末へ移してから打つ
	feed("<End>X<C-s>")
end)

step("ctrl-s result", function()
	eq("<C-s> でもディスクに書かれる", vim.fn.readfile(initial_file), { "foo barX" })
	check("<C-s> の後もインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- 行を跨いだ入力も undo が 1 塊にならない
-- ---------------------------------------------------------------------------
step("undo break reset", function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("type first line", function()
	check("行跨ぎテストの前にインサート", is_insert(), "mode=" .. mode())
	feed("foo")
end)

step("type newline", function()
	eq("1 行目を入力できる", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "foo" })
	-- 実際のキー入力と同じく、改行は前後の文字と別の入力として送る。
	-- headless で 1 回の feed にまとめると改行の undo 区切りが反映されない。
	feed("<CR>")
end)

step("type second line", function()
	eq("改行で 2 行になる", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "foo", "" })
	feed("bar")
end)

step("undo second line", function()
	eq("2 行を入力できる", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "foo", "bar" })
	check("入力後もインサート (行跨ぎ)", is_insert(), "mode=" .. mode())
	feed("<D-z>")
end)

step("after undo second line", function()
	eq("<D-z> で 2 行目だけ戻る", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "foo", "" })
	check("行跨ぎの undo 後もインサート", is_insert(), "mode=" .. mode())
	feed("<D-Z>")
end)

step("redo second line", function()
	eq("<D-Z> で 2 行目をやり直せる", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "foo", "bar" })
	check("行跨ぎの redo 後もインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- セレクト中の Cmd+Z / Cmd+Shift+Z
-- ---------------------------------------------------------------------------
step("select undo setup", function()
	check("セレクト undo の前にインサート", is_insert(), "mode=" .. mode())
	-- インサートのままバッファを空にする（stopinsert + startinsert を同じ
	-- コールバックで呼ぶと startinsert が反映されないため）
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("select undo type", function()
	check("セレクト undo の入力前にインサート", is_insert(), "mode=" .. mode())
	feed("hello")
end)

step("select undo leave insert", function()
	eq("undo 用の文字が入る", vim.fn.getline(1), "hello")
	check("入力後もインサート", is_insert(), "mode=" .. mode())
	vim.cmd.stopinsert()
end)

step("select undo enter select", function()
	check("stopinsert でノーマル", mode() == "n", "mode=" .. mode())
	feed("gh<S-Right><S-Right><S-Right><S-Right>")
end)

step("select undo invoke", function()
	eq("gh と Shift+矢印でセレクト", mode(), "s")
	feed("<D-z>")
end)

step("select undo result", function()
	local undone = vim.wait(2000, function()
		return vim.fn.getline(1) == ""
	end, 20)
	eq("セレクト中の <D-z> で入力が戻る", vim.fn.getline(1), "")
	check("セレクト中の <D-z> で戻る", undone, "line=" .. vim.fn.getline(1))
	local insert = vim.wait(5000, is_insert, 20)
	check("セレクト中の <D-z> のあとはインサート", insert, "mode=" .. mode())
end)

step("select redo stopinsert", function()
	check("セレクト redo の前にインサート", is_insert(), "mode=" .. mode())
	vim.cmd.stopinsert()
end)

step("select redo enter select", function()
	check("セレクト redo の前にノーマル", mode() == "n", "mode=" .. mode())
	feed("gh")
end)

step("select redo invoke", function()
	eq("redo の前にセレクト", mode(), "s")
	feed("<D-Z>")
end)

step("select redo result", function()
	local redone = vim.wait(2000, function()
		return vim.fn.getline(1) == "hello"
	end, 20)
	eq("セレクト中の <D-Z> でやり直せる", vim.fn.getline(1), "hello")
	check("セレクト中の <D-Z> でやり直せる", redone, "line=" .. vim.fn.getline(1))
	local insert = vim.wait(5000, is_insert, 20)
	check("セレクト中の <D-Z> のあとはインサート", insert, "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- 選択と Cmd+C / Cmd+X / Cmd+A
-- ---------------------------------------------------------------------------
step("visual copy select", function()
	vim.cmd.stopinsert()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- v で始めて 4l で "hello" の 5 文字を選ぶ（v5l だと空ける 1 文字まで入る）
	feed("v4l")
end)

step("visual copy", function()
	eq("コピー前にビジュアル", mode(), "v")
	feed("<D-c>")
end)

step("visual copy result", function()
	eq("<D-c> で + レジスタに入る", clipboard("+"), { "hello" })
	eq("<D-c> の後もビジュアルのまま", mode(), "v")
	feed("<Esc>")
end)

step("visual copy escape", function()
	check("コピー後にビジュアルを抜けるとインサート", is_insert(), "mode=" .. mode())
	vim.cmd.stopinsert()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	feed("v4l")
end)

step("cut", function()
	eq("切り取り前にビジュアル", mode(), "v")
	feed("<D-x>")
end)

step("cut result", function()
	eq("<D-x> で + レジスタに入る", clipboard("+"), { "hello" })
end)

step("cut buffer", function()
	eq("<D-x> で選択範囲が消える", vim.fn.getline(1), " world")
	check("切り取り後にインサートに戻る", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- セレクトモード（gh など）での Cmd+C / Cmd+X
-- ---------------------------------------------------------------------------
step("select copy setup", function()
	vim.cmd.stopinsert()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("select copy invoke", function()
	check("セレクトコピーの前にノーマル", mode() == "n", "mode=" .. mode())
	-- gh でセレクトに入り、Shift+矢印で選択を広げる（"hello" の 5 文字）
	feed("gh<S-Right><S-Right><S-Right><S-Right>")
end)

step("select copy", function()
	eq("gh と Shift+矢印でセレクト", mode(), "s")
	feed("<D-c>")
end)

step("select copy result", function()
	eq("セレクトモードで <D-c> が + レジスタに入る", clipboard("+"), { "hello" })
	check("<D-c> の後もセレクトのまま", mode() == "s", "mode=" .. mode())
	feed("<Esc>")
end)

step("select copy escape", function()
	check("セレクトでのコピー後にインサート", is_insert(), "mode=" .. mode())
	vim.cmd.stopinsert()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("select cut invoke", function()
	check("セレクト切り取りの前にノーマル", mode() == "n", "mode=" .. mode())
	feed("gh<S-Right><S-Right><S-Right><S-Right>")
end)

step("select cut", function()
	eq("切り取り前にセレクト", mode(), "s")
	feed("<D-x>")
end)

step("select cut result", function()
	eq("セレクトモードで <D-x> が + レジスタに入る", clipboard("+"), { "hello" })
	eq("セレクトモードで <D-x> で選択範囲が消える", vim.fn.getline(1), " world")
	check("セレクトでの切り取り後にインサート", is_insert(), "mode=" .. mode())
end)

step("select all", function()
	check("全選択の前にインサート", is_insert(), "mode=" .. mode())
	-- インサートのままバッファを差し替える（stopinsert + startinsert を
	-- 同じコールバックで呼ぶと startinsert が反映されないため）
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end)

step("select all invoke", function()
	check("全選択の前にインサート (2)", is_insert(), "mode=" .. mode())
	feed("<D-a>")
end)

step("select all result", function()
	-- 行単位のセレクトになっていること（visualmode() はセレクト中の種類を返さない）
	eq("<D-a> で行単位のセレクトモード", mode(), "S")
	eq("<D-a> の選択開始行", vim.fn.line("v"), 1)
	eq("<D-a> の選択終了行", vim.fn.line("."), 2)
	feed("X")
end)

step("replace selection", function()
	eq("セレクト中に打つと置き換わる", vim.api.nvim_buf_get_lines(0, 0, -1, false), { "X" })
	check("置き換え後はインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- ヘルプなどの特殊バッファはノーマルのまま
-- ---------------------------------------------------------------------------
step("help", function()
	feed("<Esc>")
	vim.cmd("help help")
end)

step("help buffer", function()
	eq("ヘルプは buftype=help", vim.bo.buftype, "help")
	check("ヘルプではインサートにしない", mode() == "n", "mode=" .. mode())
	vim.cmd("close")
end)

step("help closed", function()
	check("ヘルプを閉じたら通常ファイルでインサート", is_insert(), "mode=" .. mode())
end)

-- ---------------------------------------------------------------------------
-- 編集できないバッファ（buftype=nofile）へ移るとインサートを抜ける
-- （ファイル一覧・ダッシュボード・quickfix なども同じ扱い）
-- ---------------------------------------------------------------------------
local nofile_win
local editor_win

step("nofile split", function()
	check("nofile テストの前にインサート", is_insert(), "mode=" .. mode())
	editor_win = vim.api.nvim_get_current_win()
	vim.cmd("vsplit")
	-- 新しいウィンドウに、ダッシュボードなどと同じ buftype=nofile のバッファを出す
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	nofile_win = vim.api.nvim_get_current_win()
	-- いったんエディタ側のウィンドウへ戻る（WinEnter でインサートに戻る）
	vim.api.nvim_set_current_win(editor_win)
end)

step("nofile back to editor", function()
	check("nofile のウィンドウがある", nofile_win ~= nil and vim.api.nvim_win_is_valid(nofile_win))
	if nofile_win and vim.api.nvim_win_is_valid(nofile_win) then
		eq("nofile バッファの buftype", vim.bo[vim.api.nvim_win_get_buf(nofile_win)].buftype, "nofile")
	end
	local insert = vim.wait(5000, is_insert, 20)
	check("エディタ側のウィンドウでインサート", insert, "mode=" .. mode())
	-- インサート中に nofile のウィンドウへ移る（WinEnter）
	vim.api.nvim_set_current_win(nofile_win)
end)

step("nofile is normal", function()
	local normal = vim.wait(5000, function()
		return mode() == "n"
	end, 20)
	check("buftype=nofile のウィンドウへ移るとノーマル", normal, "mode=" .. mode())
	-- 後片付け：エディタ側に戻す
	if editor_win and vim.api.nvim_win_is_valid(editor_win) then
		vim.api.nvim_set_current_win(editor_win)
	end
	vim.cmd("only")
end)

step("nofile cleanup", function()
	check("nofile を閉じたらインサートに戻る", is_insert(), "mode=" .. mode())
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
	-- モード変更や feedkeys の処理が次のステップまでに反映されるよう少し待つ
	vim.defer_fn(run_next, 50)
end

if not loaded then
	finish()
else
	vim.defer_fn(run_next, 100)
end
