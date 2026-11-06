---@mod oil-download.config

---@class oil_download.Config
---@field default_keymaps boolean Map `p` in oil buffers to |<Plug>(oil-download-paste)|
---@field downloader fun(url: string, dir: string): string[] Builds the download command argv
---@field url_pattern string Lua pattern a buffer line must match to count as a URL

---@class (partial) oil_download.Opts : oil_download.Config

local M = {}

---@type oil_download.Config
M.defaults = {
  default_keymaps = true,
  downloader = function(url, dir)
    return { "wget", "-q", "-P", dir, url }
  end,
  url_pattern = "^%s*https?://%S+%s*$",
}

--- The effective config: defaults merged with `vim.g.oil_download`
--- (a table, or a function returning one). Read on every call, so changes
--- to `vim.g.oil_download` apply without a restart.
---@return oil_download.Config
function M.get()
  local user = vim.g.oil_download
  if type(user) == "function" then user = user() end
  return vim.tbl_deep_extend("force", M.defaults, user or {})
end

--- Validate the effective config.
---@return boolean ok, string? err
function M.validate()
  local cfg = M.get()
  local fields = {
    { "default_keymaps", cfg.default_keymaps, "boolean" },
    { "downloader", cfg.downloader, "function" },
    { "url_pattern", cfg.url_pattern, "string" },
  }
  return pcall(function()
    for _, f in ipairs(fields) do
      if vim.fn.has("nvim-0.11") == 1 then
        vim.validate(f[1], f[2], f[3])
      else
        vim.validate({ [f[1]] = { f[2], f[3] } }) -- 0.10 spec form
      end
    end
  end)
end

--- Keys in `vim.g.oil_download` that aren't config fields (likely typos).
---@return string[]
function M.unknown_keys()
  local user = vim.g.oil_download
  if type(user) == "function" then user = user() end
  local out = {}
  for k in pairs(user or {}) do
    if M.defaults[k] == nil then table.insert(out, tostring(k)) end
  end
  table.sort(out)
  return out
end

return M
