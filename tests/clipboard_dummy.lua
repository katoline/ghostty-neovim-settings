-- テスト用のダミークリップボード provider
-- 実際の macOS のクリップボード（pbcopy / pbpaste）を触らないようにする。
-- LazyVim が clipboard を使う前に読ませるため、nvim の --cmd から読み込む。
--
-- コピーされた内容は _G.__test_clipboard に残すので、テストから検証できる。

_G.__test_clipboard = {
	["+"] = { lines = {}, regtype = "v" },
	["*"] = { lines = {}, regtype = "v" },
}

local function make_copy(reg)
	return function(lines, regtype)
		_G.__test_clipboard[reg] = { lines = lines, regtype = regtype }
	end
end

local function make_paste(reg)
	return function()
		return _G.__test_clipboard[reg].lines
	end
end

vim.g.clipboard = {
	name = "modeless-test",
	copy = {
		["+"] = make_copy("+"),
		["*"] = make_copy("*"),
	},
	paste = {
		["+"] = make_paste("+"),
		["*"] = make_paste("*"),
	},
	cache_enabled = true,
}
