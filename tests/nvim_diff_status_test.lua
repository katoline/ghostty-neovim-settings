-- gitsigns と bufferline の見た目設定の headless 統合テスト
--
-- tests/run_nvim_diff_status_test.sh から、ユーザーの実際の LazyVim 設定
-- （~/.config/nvim）を読み込んだ nvim で実行する。
-- カレントディレクトリはテスト用の一時ディレクトリで、ファイルは開かない。
--
-- 確かめること:
--   * gitsigns: 変更行のサイン（追加・変更は ┃、削除は _）と、
--     行番号の着色（numhl）・行全体の着色（linehl）が有効になっている
--   * gitsigns: LazyVim が用意している ]h と <leader>ghs のキーマップが残っている
--   * bufferline: 未保存の印が ✱ で、色が #e0af68（太字）になっている
--   * 新規バッファに文字を入れると未保存（modified）になる
--
-- gitsigns の attach（実際の hunk 取得）は headless では確認できないため対象外。
-- headless では UIEnter が来ないため VeryLazy が自動では発火しない。
-- bufferline の設定はテスト側で VeryLazy を 1 回だけ発火させてから確認する。

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

local test_path = vim.env.NVIM_DIFF_TEST
if not test_path or test_path == "" then
	vim.api.nvim_err_writeln("NVIM_DIFF_TEST がありません")
	vim.cmd("cquit 1")
end

-- テスト中に undo ファイル・スワップファイルを作らない
vim.opt.undofile = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- 何かの拍子に終わらない場合でも、必ず有限時間で失敗させる。
-- VimEnter を待つ前から仕掛けておき、finish() で止める。
local timeout = vim.defer_fn(function()
	vim.api.nvim_err_writeln("テストがタイムアウトしました")
	vim.cmd("cquit 1")
end, 120000)

-- headless では VimEnter がまだのことがあるので待つ
vim.wait(10000, function()
	return vim.v.vim_did_enter == 1
end, 20)

-- ---------------------------------------------------------------------------
-- gitsigns（変更行のサイン・行番号の着色・行全体の着色）
-- ---------------------------------------------------------------------------
local loaded, load_err = pcall(function()
	require("lazy").load({ plugins = { "gitsigns.nvim" } })
end)
check("gitsigns.nvim を読み込める", loaded, tostring(load_err))

local gitsigns_ok, gitsigns_config = pcall(function()
	return require("gitsigns.config").config
end)
check("gitsigns の設定を取得できる", gitsigns_ok, tostring(gitsigns_config))

if gitsigns_ok and type(gitsigns_config) == "table" then
	check("gitsigns: numhl = true（行番号を着色する）", gitsigns_config.numhl == true, vim.inspect(gitsigns_config.numhl))
	check(
		"gitsigns: linehl = true（行全体を着色する）",
		gitsigns_config.linehl == true,
		vim.inspect(gitsigns_config.linehl)
	)

	local signs = gitsigns_config.signs or {}
	local function sign_text(kind)
		return (signs[kind] or {}).text
	end

	eq("gitsigns: 追加のサインが ┃", sign_text("add"), "┃")
	eq("gitsigns: 変更のサインが ┃", sign_text("change"), "┃")
	eq("gitsigns: 削除のサインが _", sign_text("delete"), "_")
	eq("gitsigns: 上端削除のサインが ‾", sign_text("topdelete"), "‾")
	eq("gitsigns: 変更＋削除のサインが ~", sign_text("changedelete"), "~")
end

-- LazyVim の gitsigns のキーマップ（]h: 次の hunk、<leader>ghs: ステージ）が残っている。
-- LazyVim は on_attach でキーマップを設定するが、headless では実ファイルへの attach
-- （hunk の取得）を確認できないため、attach 自体は行わず、on_attach を現在のバッファに
-- 対して直接呼んで、nvim.lua の opts が LazyVim の on_attach を消していないことを確かめる。
local on_attach = type(gitsigns_config) == "table" and gitsigns_config.on_attach or nil
if type(on_attach) == "function" then
	local attach_ok, attach_err = pcall(on_attach, vim.api.nvim_get_current_buf())
	check("gitsigns: LazyVim の on_attach を実行できる", attach_ok, tostring(attach_err))
else
	check("gitsigns: LazyVim の on_attach がある", false, vim.inspect(on_attach))
end

for _, lhs in ipairs({ "]h", "<leader>ghs" }) do
	local mapped = vim.fn.maparg(lhs, "n")
	check(
		("gitsigns: LazyVim のキーマップ %s が残っている"):format(lhs),
		mapped ~= "",
		("maparg: " .. vim.inspect(mapped))
	)
end

-- ---------------------------------------------------------------------------
-- bufferline（未保存の印と色）
-- ---------------------------------------------------------------------------
-- headless では VeryLazy が自動で来ないので、ここで 1 回だけ発火させる
local fired, fire_err = pcall(function()
	vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
end)
check("VeryLazy を発火できる", fired, tostring(fire_err))

local bufferline_ok, bufferline_config = pcall(function()
	return require("bufferline.config").get()
end)
check("bufferline の設定を取得できる", bufferline_ok, tostring(bufferline_config))

if bufferline_ok and type(bufferline_config) == "table" then
	local options = bufferline_config.options or {}
	local highlights = bufferline_config.highlights or {}
	local user_highlights = (bufferline_config.user or {}).highlights or {}
	local modified = highlights.modified or {}
	local modified_visible = highlights.modified_visible or {}
	local modified_selected = highlights.modified_selected or {}

	eq("bufferline: 未保存の印が ✱", options.modified_icon, "✱")
	eq("bufferline: modified の色が #e0af68", modified.fg, "#e0af68")
	check("bufferline: modified が太字", modified.bold == true, vim.inspect(modified))
	eq("bufferline: modified_visible の色が #e0af68", modified_visible.fg, "#e0af68")
	check("bufferline: modified_visible が太字", modified_visible.bold == true, vim.inspect(modified_visible))
	eq("bufferline: modified_selected の色が #e0af68", modified_selected.fg, "#e0af68")
	check(
		"bufferline: modified_selected が太字",
		modified_selected.bold == true,
		vim.inspect(modified_selected)
	)

	-- 背景色は bufferline の既定（colorscheme から決まる色）を残すため、指定していないことを確かめる
	local user_modified = user_highlights.modified or {}
	local user_modified_visible = user_highlights.modified_visible or {}
	local user_modified_selected = user_highlights.modified_selected or {}
	check("bufferline: modified の背景色を指定していない", user_modified.bg == nil, vim.inspect(user_modified))
	check(
		"bufferline: modified_visible の背景色を指定していない",
		user_modified_visible.bg == nil,
		vim.inspect(user_modified_visible)
	)
	check(
		"bufferline: modified_selected の背景色を指定していない",
		user_modified_selected.bg == nil,
		vim.inspect(user_modified_selected)
	)
end

-- ---------------------------------------------------------------------------
-- 未保存の判定
-- ---------------------------------------------------------------------------
-- ファイルを持たない新規バッファに文字を入れて、modified になることを確かめる
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved" })
check("新規バッファ: 文字を入れると未保存になる", vim.bo[buf].modified == true, vim.inspect(vim.bo[buf].modified))

-- ---------------------------------------------------------------------------
-- 実行
-- ---------------------------------------------------------------------------
local function finish()
	pcall(function()
		timeout:stop()
	end)
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

finish()
