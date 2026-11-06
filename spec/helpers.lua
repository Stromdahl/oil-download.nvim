-- Shared setup for specs: real oil.nvim, this plugin on the runtimepath, and a
-- recording downloader so no test touches the network.
local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

--- Notifications captured instead of printed: { {msg, level}, ... }
M.notes = {}
vim.notify = function(msg, level) table.insert(M.notes, { msg = msg, level = level }) end

local booted = false
function M.boot()
  if booted then return end
  booted = true
  -- In-memory clipboard: CI has no clipboard tool, and tests shouldn't touch
  -- the real one.
  local clip = { ["+"] = { { "" }, "v" }, ["*"] = { { "" }, "v" } }
  local function copy(reg)
    return function(lines, regtype) clip[reg] = { lines, regtype } end
  end
  local function paste(reg)
    return function() return clip[reg] end
  end
  vim.g.clipboard = {
    name = "spec",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
  vim.opt.runtimepath:prepend(root)
  vim.cmd("filetype plugin on")
  vim.cmd("syntax on")
  require("oil").setup({ skip_confirm_for_simple_edits = false })
  vim.cmd.runtime("plugin/oil-download.lua")
end

--- Fresh temp dir with a downloader that appends "<url>" lines to <dir>/.downloads
---@return string dir absolute, with trailing slash
function M.tmpdir()
  local dir = vim.fn.tempname() .. "/"
  vim.fn.mkdir(dir, "p")
  return dir
end

M.recorder = function(url, dir) return { "sh", "-c", 'printf "%s\\n" "$1" >> "$2/.downloads"', "sh", url, dir } end

---@return string[]
function M.downloads(dir)
  local f = io.open(dir .. ".downloads")
  if not f then return {} end
  local out = {}
  for line in f:lines() do
    table.insert(out, line)
  end
  f:close()
  return out
end

--- Wait until `n` downloads are recorded (or `timeout` ms pass; use a short
--- timeout when asserting that nothing gets downloaded).
function M.wait_downloads(dir, n, timeout)
  vim.wait(timeout or 3000, function() return #M.downloads(dir) >= n end, 20)
  return M.downloads(dir)
end

--- Drop all buffers and unsaved oil edits. Call after each test: a modified
--- buffer left behind makes headless nvim wait on a prompt at exit.
function M.reset()
  pcall(require("oil").discard_all_changes)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then vim.bo[b].modified = false end
  end
  vim.cmd("silent! %bwipeout!")
end

--- Open oil on `dir` and wait for it to render. Starts from a clean slate
--- unless `opts.keep`, which keeps the other (possibly modified) oil buffers.
---@param opts? { keep?: boolean }
function M.open(dir, opts)
  if not (opts and opts.keep) then M.reset() end
  require("oil").open(dir)
  vim.wait(
    3000,
    function()
      return vim.bo.filetype == "oil"
        and require("oil").get_current_dir() == dir
        and #vim.api.nvim_buf_get_lines(0, 0, -1, false) > 0
    end,
    20
  )
  -- oil renders asynchronously; let it settle
  vim.wait(200)
end

function M.lines(buf) return vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false) end

--- Append lines to the current oil buffer, :w, then answer the dialog.
---@param answer "y"|"n"
function M.write_and_answer(answer)
  local oil_buf = vim.api.nvim_get_current_buf()
  vim.cmd("w")
  local ok = vim.wait(3000, function() return vim.bo.filetype == "oil_preview" end, 10)
  assert(ok, "oil confirmation dialog did not open")
  local dialog = M.lines()
  vim.api.nvim_feedkeys(answer, "x", false)
  vim.wait(3000, function() return vim.api.nvim_get_current_buf() == oil_buf end, 10)
  vim.wait(300)
  return dialog
end

--- Names of the files in `dir` (excluding the recorder log)
function M.files(dir)
  local out = {}
  for name in vim.fs.dir(dir) do
    if name ~= ".downloads" then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

return M
