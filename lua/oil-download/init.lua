local config = require("oil-download.config")

local M = {}

--- Store options in `vim.g.oil_download`. Optional: the plugin works
--- without calling it. If `vim.g.oil_download` is a function, it stays one
--- (still called on every use), with `opts` merged over its result.
---@param opts? oil_download.Opts
function M.setup(opts)
  opts = opts or {}
  local current = vim.g.oil_download
  if type(current) == "function" then
    vim.g.oil_download = function() return vim.tbl_deep_extend("force", config.read_user(current), opts) end
  else
    vim.g.oil_download = vim.tbl_deep_extend("force", config.read_user(), opts)
  end
end

---@param line string
---@return boolean
function M.is_url(line)
  return line:match(config.get().url_pattern) ~= nil
end

--- Directory downloads go to: the oil directory of `buf` (default: current
--- buffer), else the working directory.
---@param buf? integer
---@return string
function M.target_dir(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf):match("^oil://") then
    local ok, oil = pcall(require, "oil")
    local dir = ok and oil.get_current_dir(buf)
    if dir then return dir end
  end
  return vim.fn.getcwd()
end

--- Download `url` into `dir` in the background.
---@param url string
---@param dir? string defaults to |oil-download.target_dir()|
function M.download(url, dir)
  url = vim.trim(url or "")
  if url == "" then return end
  dir = dir or M.target_dir()
  local argv = config.get().downloader(url, dir)
  vim.notify("Downloading " .. url)
  local ok, err = pcall(vim.system, argv, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        vim.notify("Downloaded " .. url .. " into " .. dir)
      else
        local msg = vim.trim(res.stderr or "")
        vim.notify(
          ("Download failed (%s exited %d): %s%s"):format(argv[1], res.code, url, msg ~= "" and ("\n" .. msg) or ""),
          vim.log.levels.ERROR
        )
      end
    end)
  end)
  if not ok then vim.notify("Download failed: " .. tostring(err), vim.log.levels.ERROR) end
end

--- Split a register into non-empty trimmed lines.
---@param reg string
---@return string[]
local function register_lines(reg)
  local lines = vim.split(vim.fn.getreg(reg), "\n")
  return vim.tbl_filter(function(l) return l ~= "" end, vim.tbl_map(vim.trim, lines))
end

--- `p` for oil buffers: if the register holds only URLs, put each on its own
--- line below the cursor (they're downloaded on :w); otherwise a normal `p`.
function M.paste()
  local reg, count = vim.v.register, vim.v.count1
  local lines = register_lines(reg)
  if #lines > 0 and vim.iter(lines):all(M.is_url) then
    local current = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    if #current == 1 and current[1] == "" then
      -- empty directory: oil shows one blank line; replace it
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    else
      vim.api.nvim_put(lines, "l", true, true)
    end
  else
    vim.cmd(("normal! %d\"%sp"):format(count, reg))
  end
end

--- Ask for a URL (prefilled from the clipboard) and download it right away.
function M.prompt()
  local dir = M.target_dir()
  vim.ui.input({ prompt = "Download URL: ", default = vim.fn.getreg("+") }, function(url)
    if url then M.download(url, dir) end
  end)
end

---@class oil_download.Stripped
---@field buf integer
---@field dir string
---@field rows integer[] 1-based line numbers the URLs were on
---@field urls string[]

--- Remove URL lines from every modified oil buffer (oil saves them all at once).
---@return oil_download.Stripped[]
local function strip_all()
  local out = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].modified
      and vim.api.nvim_buf_get_name(buf):match("^oil://")
    then
      local rows, urls = {}, {}
      for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if M.is_url(line) then
          table.insert(rows, i)
          table.insert(urls, vim.trim(line))
        end
      end
      if #urls > 0 then
        for i = #rows, 1, -1 do
          vim.api.nvim_buf_set_lines(buf, rows[i] - 1, rows[i], false, {})
        end
        table.insert(out, { buf = buf, dir = M.target_dir(buf), rows = rows, urls = urls })
      end
    end
  end
  return out
end

---@param stripped oil_download.Stripped[]
local function restore(stripped)
  for _, s in ipairs(stripped) do
    local current = vim.api.nvim_buf_is_valid(s.buf) and vim.api.nvim_buf_get_lines(s.buf, 0, -1, false)
    if current and #current == 1 and current[1] == "" then
      -- stripping emptied the buffer down to the one line nvim always keeps
      vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, s.urls)
    elseif current then
      for i, row in ipairs(s.rows) do
        vim.api.nvim_buf_set_lines(s.buf, row - 1, row - 1, false, { s.urls[i] })
      end
    end
  end
end

---@param stripped oil_download.Stripped[]
local function download_all(stripped)
  for _, s in ipairs(stripped) do
    for _, url in ipairs(s.urls) do
      M.download(url, s.dir)
    end
  end
end

--- BufWritePre handler for oil buffers. Oil fires BufWritePre before parsing
--- the buffer, so URL lines are removed before oil can mistake them for paths.
function M.on_write()
  local stripped = strip_all()
  if #stripped == 0 then return end
  local urls = {}
  for _, s in ipairs(stripped) do
    vim.list_extend(urls, s.urls)
  end

  local hook = require("oil-download.oil_hook")
  ---@type oil_download.Batch
  local batch = {
    urls = urls,
    on_answer = function(proceed)
      if proceed then
        download_all(stripped)
      else
        -- after oil has unlocked the buffer; like oil, keep a cancelled edit
        vim.schedule(function() restore(stripped) end)
      end
    end,
  }

  if hook.queue(batch) then
    -- Oil opens the dialog synchronously within this :w. If it didn't
    -- (parse error elsewhere in the buffer), give the lines back.
    vim.schedule(function()
      if hook.take_back(batch) then
        hook.keep_diagnostics(stripped, function() restore(stripped) end)
      end
    end)
    return
  end

  -- Fallback: oil internals changed. Ask with our own prompt instead.
  local by_dir, dirs = {}, {}
  for _, s in ipairs(stripped) do
    if not by_dir[s.dir] then
      by_dir[s.dir] = {}
      table.insert(dirs, s.dir)
    end
    vim.list_extend(by_dir[s.dir], s.urls)
  end
  local parts = { "Download?" }
  for _, dir in ipairs(dirs) do
    table.insert(parts, "\nInto " .. dir .. "\n  " .. table.concat(by_dir[dir], "\n  "))
  end
  local msg = table.concat(parts, "\n")
  if vim.fn.confirm(msg, "&Yes\n&No", 1) == 1 then
    download_all(stripped)
  else
    -- Said up front: if oil's internals moved, the put-back below may not stick.
    vim.notify("Skipped downloads:\n" .. table.concat(urls, "\n"), vim.log.levels.WARN)
    hook.after_save(function() restore(stripped) end)
  end
end

return M
