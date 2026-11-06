-- Default `p` in oil buffers. Skipped when the user opted out, already mapped
-- <Plug>(oil-download-paste) themselves, or has a buffer-local `p` (e.g. from
-- oil's own `keymaps`, which oil sets after this file runs anyway).
local cfg = require("oil-download.config").get()
if not cfg.default_keymaps then return end
if vim.fn.hasmapto("<Plug>(oil-download-paste)", "n") == 1 then return end
if vim.fn.maparg("p", "n", false, true).buffer == 1 then return end

vim.keymap.set("n", "p", "<Plug>(oil-download-paste)", {
  buffer = 0, -- `buf` from 0.12 on; `buffer` still works and covers 0.10/0.11
  desc = "Paste; URLs become lines downloaded on :w",
})
