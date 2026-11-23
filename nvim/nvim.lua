-- lazy.nvim のプラグイン spec
-- ~/.config/nvim/lua/plugins/terminal.lua としてリンクされ、LazyVim が読み込む
return {
	{
		"akinsho/toggleterm.nvim", -- Neovim 内ターミナルのプラグイン
		version = "*",
		opts = {}, -- 既定の設定を使う
	},
}
