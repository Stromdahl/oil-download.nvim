if vim.g.loaded_oil_download then return end
vim.g.loaded_oil_download = true

if vim.fn.has("nvim-0.10") == 0 then
  vim.notify_once("oil-download.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end

-- Everything here is cheap; modules load on first use. Never require("oil")
-- at startup, so load order relative to oil doesn't matter.

vim.keymap.set(
  "n",
  "<Plug>(oil-download-paste)",
  function() require("oil-download").paste() end,
  { desc = "Paste; URLs become lines downloaded on :w" }
)

vim.keymap.set(
  "n",
  "<Plug>(oil-download-prompt)",
  function() require("oil-download").prompt() end,
  { desc = "Download a URL into the current directory" }
)

vim.api.nvim_create_user_command("OilDownload", function(args)
  if args.args ~= "" then
    require("oil-download").download(args.args)
  else
    require("oil-download").prompt()
  end
end, { nargs = "?", desc = "Download a URL into the current oil directory" })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("oil-download", { clear = true }),
  pattern = "oil://*",
  callback = function() require("oil-download").on_write() end,
})
