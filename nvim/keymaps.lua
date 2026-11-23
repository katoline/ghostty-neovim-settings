-- 右側にターミナル（縦分割）を開く
vim.keymap.set("n", "<leader>tv", function()
	require("toggleterm").toggle(1, 80, nil, "vertical")
end, { desc = "Toggle Vertical Terminal" })
