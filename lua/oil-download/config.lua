---@class oil_download.Config
---@field default_keymaps boolean Map `p` in oil buffers to |<Plug>(oil-download-paste)|
---@field downloader fun(url: string, dir: string): string[] Builds the download command argv
---@field url_pattern string Lua pattern a buffer line must match to count as a URL

---@class (partial) oil_download.Opts : oil_download.Config

---@type oil_download.Opts|fun():oil_download.Opts|nil
vim.g.oil_download = vim.g.oil_download

local M = {}

---@type oil_download.Config
M.defaults = {
  default_keymaps = true,
  downloader = function(url, dir)
    return { "wget", "-q", "-P", dir, url }
  end,
  url_pattern = "^%s*https?://%S+%s*$",
}

--- `user` (default: `vim.g.oil_download`) as a table: called first if it is
--- a function; anything but a table reads as no options.
---@param user? oil_download.Opts|fun():oil_download.Opts
---@return oil_download.Opts
function M.read_user(user)
  if user == nil then user = vim.g.oil_download end
  if type(user) == "function" then user = user() end
  return type(user) == "table" and user or {}
end

---@param name string
---@param value any
---@return string? err
local function check(name, value)
  local expected = type(M.defaults[name])
  local ok, err = pcall(function()
    if vim.fn.has("nvim-0.11") == 1 then
      vim.validate(name, value, expected)
    else
      vim.validate({ [name] = { value, expected } }) -- 0.10 spec form
    end
  end)
  return not ok and tostring(err) or nil
end

--- Defaults merged with `vim.g.oil_download`, invalid fields left at their
--- defaults.
---@return oil_download.Config cfg, string[] errors
local function resolve()
  local cfg = vim.tbl_deep_extend("force", M.defaults, M.read_user())
  local errors = {}
  for name in pairs(M.defaults) do
    local err = check(name, cfg[name])
    if err then
      table.insert(errors, err)
      cfg[name] = M.defaults[name]
    end
  end
  table.sort(errors)
  return cfg, errors
end

--- The effective config. Read on every call, so changes to
--- `vim.g.oil_download` apply without a restart. An invalid option is
--- reported once and replaced by its default.
---@return oil_download.Config
function M.get()
  local cfg, errors = resolve()
  if #errors > 0 then
    vim.notify_once(
      "oil-download: invalid config, using defaults for:\n" .. table.concat(errors, "\n"),
      vim.log.levels.ERROR
    )
  end
  return cfg
end

--- Validate the effective config.
---@return boolean ok, string? err
function M.validate()
  local _, errors = resolve()
  if #errors > 0 then return false, table.concat(errors, "; ") end
  return true
end

--- Keys in `vim.g.oil_download` that aren't config fields (likely typos).
---@return string[]
function M.unknown_keys()
  local out = {}
  for k in pairs(M.read_user()) do
    if M.defaults[k] == nil then table.insert(out, tostring(k)) end
  end
  table.sort(out)
  return out
end

--- The config field names, sorted.
---@return string[]
function M.keys()
  local out = vim.tbl_keys(M.defaults)
  table.sort(out)
  return out
end

return M
