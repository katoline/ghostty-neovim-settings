-- Snacks のファイル一覧・ファイル名検索・grep の表示の headless 統合テスト
--
-- tests/run_nvim_hidden_files_test.sh から、ユーザーの実際の LazyVim 設定
-- （~/.config/nvim）を読み込んだ nvim で実行する。
-- カレントディレクトリ（NVIM_HIDDEN_CWD）はテスト用の一時ディレクトリの
-- git リポジトリで、次のファイルがある。
--   a.txt / .hidden.txt / .gitignore（ignored.txt を無視）/ ignored.txt
--   .claude/settings.json
--
-- 確かめること（.claude のようなドットファイルと .gitignore されたファイルが見える）:
--   * ファイル一覧（explorer）: .claude（開くと settings.json）・ .hidden.txt・ ignored.txt が出る
--   * ファイル名検索（files）: .claude/settings.json・ .hidden.txt・ ignored.txt が出る
--   * grep / grep_word: .claude/settings.json・ .hidden.txt・ ignored.txt が検索対象になる
--   * どれも .git の中身は出ない
--
-- headless では UIEnter が来ないため VeryLazy が自動では発火しない。
-- VeryLazy は使わない（keymaps に依存しないテストのため）。

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

local cwd = vim.env.NVIM_HIDDEN_CWD
if not cwd or cwd == "" then
	vim.api.nvim_err_writeln("NVIM_HIDDEN_CWD がありません")
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

-- ピッカーのアイテムのファイルパス（explorer は絶対パス、files / grep は cwd からの相対パス）
local function item_files(picker)
	local files = {}
	if not picker or not picker.finder then
		return files
	end
	for _, item in ipairs(picker.finder.items or {}) do
		if item.file then
			files[#files + 1] = item.file
		end
	end
	return files
end

local function abs(file)
	if file:sub(1, 1) == "/" then
		return file
	end
	return cwd .. "/" .. file
end

-- path が cwd からの相対パス（例: .claude/settings.json）のアイテムとして出ているか
local function has_file(picker, path)
	local want = cwd .. "/" .. path
	for _, file in ipairs(item_files(picker)) do
		if abs(file) == want then
			return true
		end
	end
	return false
end

-- .git 本体や .git/ の中身が混ざっていないか（.gitignore は対象外）
local function git_entries(picker)
	local found = {}
	for _, file in ipairs(item_files(picker)) do
		local path = abs(file)
		if path == cwd .. "/.git" or path:find("/.git/", 1, true) then
			found[#found + 1] = path
		end
	end
	return found
end

local function wait_for(name, picker_fn, min_items)
	local ok = vim.wait(15000, function()
		local picker = picker_fn()
		return picker and picker.finder and #item_files(picker) >= min_items
	end, 100)
	check(name .. " のアイテムが読み込まれる", ok, vim.inspect(item_files(picker_fn())))

	return picker_fn()
end

local explorer ---@type snacks.Picker?
local files_picker ---@type snacks.Picker?
local grep_picker ---@type snacks.Picker?
local grep_word_picker ---@type snacks.Picker?
local scratch_buf ---@type number?

-- explorer を一時ディレクトリで開き、リストが描画されるまで待つ
Snacks.explorer({ cwd = cwd })
explorer = wait_for("explorer", function()
	return Snacks.picker.get({ source = "explorer" })[1]
end, 3)

local steps = {}
local function step(name, fn)
	steps[#steps + 1] = { name = name, fn = fn }
end

-- ---------------------------------------------------------------------------
-- ファイル一覧（explorer）
-- ---------------------------------------------------------------------------
step("explorer", function()
	if not explorer then
		check("explorer が開く", false)
		return
	end
	check("explorer: .claude が見える", has_file(explorer, ".claude"), vim.inspect(item_files(explorer)))
	check("explorer: .gitignore が見える", has_file(explorer, ".gitignore"), vim.inspect(item_files(explorer)))
	check("explorer: .hidden.txt が見える", has_file(explorer, ".hidden.txt"), vim.inspect(item_files(explorer)))
	check(
		"explorer: .gitignore された ignored.txt が見える",
		has_file(explorer, "ignored.txt"),
		vim.inspect(item_files(explorer))
	)
	check("explorer: .git は出ない", #git_entries(explorer) == 0, vim.inspect(git_entries(explorer)))

	-- .claude を選んで確定（フォルダを開く）
	local idx
	for i, item in ipairs(explorer.finder.items or {}) do
		if abs(item.file) == cwd .. "/.claude" then
			idx = i
		end
	end
	check("explorer: .claude の行がある", idx ~= nil)
	if idx then
		explorer.list:_move(idx, true, true)
		explorer:action("confirm")
	end
end)

step("explorer expanded", function()
	local opened = vim.wait(15000, function()
		return has_file(explorer, ".claude/settings.json")
	end, 100)
	check(
		"explorer: .claude を開くと settings.json が見える",
		opened,
		vim.inspect(item_files(explorer))
	)
end)

-- ---------------------------------------------------------------------------
-- ファイル名検索（files: Cmd+P / <leader>ff と同じ）
-- ---------------------------------------------------------------------------
step("files", function()
	if explorer then
		explorer:close()
	end
	Snacks.picker.files({ cwd = cwd })
	files_picker = wait_for("files", function()
		return Snacks.picker.get({ source = "files" })[1]
	end, 3)
	if not files_picker then
		check("files ピッカーが開く", false)
		return
	end
	local got = vim.inspect(item_files(files_picker))
	check("files: .claude/settings.json が見える", has_file(files_picker, ".claude/settings.json"), got)
	check("files: .gitignore が見える", has_file(files_picker, ".gitignore"), got)
	check("files: .hidden.txt が見える", has_file(files_picker, ".hidden.txt"), got)
	check("files: .gitignore された ignored.txt が見える", has_file(files_picker, "ignored.txt"), got)
	check("files: .git は出ない", #git_entries(files_picker) == 0, vim.inspect(git_entries(files_picker)))
end)

-- ---------------------------------------------------------------------------
-- grep（<leader>/ / <leader>sg と同じ）
-- ---------------------------------------------------------------------------
step("grep", function()
	if files_picker then
		files_picker:close()
	end
	Snacks.picker.grep({ cwd = cwd, search = "needle" })
	grep_picker = wait_for("grep", function()
		return Snacks.picker.get({ source = "grep" })[1]
	end, 2)
	if not grep_picker then
		check("grep ピッカーが開く", false)
		return
	end
	local got = vim.inspect(item_files(grep_picker))
	check("grep: .claude/settings.json が検索される", has_file(grep_picker, ".claude/settings.json"), got)
	check("grep: .hidden.txt が検索される", has_file(grep_picker, ".hidden.txt"), got)
	check("grep: .gitignore された ignored.txt が検索される", has_file(grep_picker, "ignored.txt"), got)
	check("grep: .git は検索しない", #git_entries(grep_picker) == 0, vim.inspect(git_entries(grep_picker)))
end)

-- ---------------------------------------------------------------------------
-- grep_word（<leader>sw と同じ。カーソルの単語を検索する）
-- ---------------------------------------------------------------------------
step("grep_word", function()
	if grep_picker then
		grep_picker:close()
	end
	-- 一時ディレクトリの外にファイルを作らずに、カーソルの単語を用意する
	scratch_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, { "needle" })
	vim.api.nvim_win_set_buf(0, scratch_buf)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	Snacks.picker.grep_word({ cwd = cwd })
	grep_word_picker = wait_for("grep_word", function()
		return Snacks.picker.get({ source = "grep_word" })[1]
	end, 2)
	if not grep_word_picker then
		check("grep_word ピッカーが開く", false)
		return
	end
	local got = vim.inspect(item_files(grep_word_picker))
	check(
		"grep_word: .claude/settings.json が検索される",
		has_file(grep_word_picker, ".claude/settings.json"),
		got
	)
	check("grep_word: .hidden.txt が検索される", has_file(grep_word_picker, ".hidden.txt"), got)
	check(
		"grep_word: .gitignore された ignored.txt が検索される",
		has_file(grep_word_picker, "ignored.txt"),
		got
	)
	check("grep_word: .git は検索しない", #git_entries(grep_word_picker) == 0, vim.inspect(git_entries(grep_word_picker)))
end)

step("cleanup", function()
	if grep_word_picker then
		grep_word_picker:close()
	end
	if scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end
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
	-- ピッカーの描画・ファイル監視の反映が次のステップまでに済むよう待つ
	vim.defer_fn(run_next, 300)
end

vim.defer_fn(run_next, 300)
