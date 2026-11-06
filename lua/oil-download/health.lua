local M = {}

--- Where oil.nvim is loaded from, plus its git version when it is a checkout.
---@return string?
local function oil_location()
  local file = vim.api.nvim_get_runtime_file("lua/oil/init.lua", false)[1]
  if not file then
    -- installed as a rock (on package.path, not the runtimepath)
    file = package.searchpath("oil", package.path)
    return file and vim.fn.fnamemodify(file, ":h")
  end
  local root = vim.fn.fnamemodify(file, ":h:h:h")
  if vim.uv.fs_stat(root .. "/.git") then
    local res = vim.system({ "git", "-C", root, "describe", "--tags", "--always" }, { text = true }):wait()
    if res.code == 0 then return ("%s (%s)"):format(root, vim.trim(res.stdout)) end
  end
  return root
end

function M.check()
  local health = vim.health
  local config = require("oil-download.config")

  health.start("oil-download: config")
  local ok, err = config.validate()
  if ok then
    health.ok("vim.g.oil_download is valid")
  else
    health.error("Invalid config: " .. tostring(err))
  end
  local unknown = config.unknown_keys()
  if #unknown > 0 then
    health.warn("Unknown keys in vim.g.oil_download: " .. table.concat(unknown, ", "), {
      "Valid keys: default_keymaps, downloader, url_pattern",
    })
  end

  health.start("oil-download: downloader")
  if ok then
    local argv = config.get().downloader("https://example.com/", vim.fn.getcwd())
    local exe = type(argv) == "table" and argv[1]
    if type(exe) ~= "string" then
      health.error("downloader() must return a command list like { 'wget', ... }")
    elseif vim.fn.executable(exe) == 1 then
      health.ok(("`%s` found: %s"):format(exe, vim.fn.exepath(exe)))
    else
      health.error(("`%s` is not installed or not on PATH"):format(exe), {
        "Install it, or set vim.g.oil_download.downloader to a command you have (e.g. curl)",
      })
    end
  end

  health.start("oil-download: oil.nvim")
  if not pcall(require, "oil") then
    health.error("oil.nvim is not installed", { "https://github.com/stevearc/oil.nvim" })
    return
  end
  health.ok("oil.nvim found: " .. (oil_location() or "?"))

  local hook = require("oil-download.oil_hook")
  local available, reason = hook.available()
  if available then
    health.ok("oil confirmation hook points present; DOWNLOAD lines go in oil's dialog")
    if hook.installed() then health.info("Dialog hook installed (happens on the first save with URLs)") end
  else
    health.warn("Running in fallback mode: " .. tostring(reason), {
      "oil.nvim changed internals this plugin relies on; downloads are confirmed with a separate prompt",
      "Please report your oil.nvim version at https://github.com/Stromdahl/oil-download.nvim/issues",
    })
  end
end

return M
