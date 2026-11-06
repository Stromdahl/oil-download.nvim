-- Every use of oil.nvim *internals* lives in this file, so an oil upgrade that
-- breaks the plugin breaks exactly one module (and spec/oil_contract_spec.lua).
--
-- Oil has no public hook for adding lines to its [Y]es/[N]o dialog, so we:
--   * wrap `require("oil.mutator.confirmation").show`, which oil's mutator
--     calls through the module table on every save, and
--   * register a tiny fake adapter for the `oil-download://` scheme, because
--     the dialog renders each action via its adapter's `render_action`.
-- The fake actions only ever reach the dialog: oil's mutator keeps its own
-- action list, so they are never executed by oil.

local M = {}

local SCHEME = "oil-download://"

---@class oil_download.Batch
---@field urls string[]
---@field on_answer fun(proceed: boolean) Called after oil has handled the answer

---@type oil_download.Batch?
local pending

-- Install state lives on oil's module table, not in this module: it must
-- survive this module being reloaded (`:Lazy reload`), and it pins oil's real
-- `show` once, so a plugin that wraps `show` after us is never mistaken for it.
local STATE = "_oil_download_hook"

---@class oil_download.HookState
---@field original function oil's own show, captured once
---@field wrapper function what we put in its place

---@return table? confirmation, table? config, string? reason
local function internals()
  local ok_c, confirmation = pcall(require, "oil.mutator.confirmation")
  if not ok_c or type(confirmation) ~= "table" or type(confirmation.show) ~= "function" then
    return nil, nil, "oil.mutator.confirmation.show not found"
  end
  local ok_cfg, config = pcall(require, "oil.config")
  if not ok_cfg or type(config) ~= "table" or type(config._adapter_by_scheme) ~= "table" then
    return nil, nil, "oil.config._adapter_by_scheme not found"
  end
  return confirmation, config
end

--- Whether the oil internals we rely on are present.
---@return boolean ok, string? reason
function M.available()
  local confirmation, _, reason = internals()
  return confirmation ~= nil, reason
end

--- Whether our dialog wrapper is currently installed.
---@return boolean
function M.installed()
  local ok, confirmation = pcall(require, "oil.mutator.confirmation")
  return ok and type(confirmation) == "table" and confirmation[STATE] ~= nil
end

---@param original function
function M._show(original, actions, should_confirm, cb)
  local batch = pending
  pending = nil
  if not batch then return original(actions, should_confirm, cb) end

  local shown = {}
  for _, url in ipairs(batch.urls) do
    table.insert(shown, { type = "download", url = SCHEME .. "download", label = url })
  end
  vim.list_extend(shown, actions)
  -- Downloads always deserve a prompt, even when oil would skip it for a
  -- "simple edit"; an explicit `oil.save({ confirm = false })` still wins.
  if should_confirm == nil then should_confirm = true end

  return original(shown, should_confirm, function(proceed)
    cb(proceed)
    batch.on_answer(proceed)
  end)
end

local function install(confirmation, config)
  if not confirmation[STATE] then
    local original = confirmation.show
    ---@type oil_download.HookState
    local state = {
      original = original,
      -- Dispatch through package.loaded so a reloaded module takes over.
      wrapper = function(...) return require("oil-download.oil_hook")._show(original, ...) end,
    }
    confirmation[STATE] = state
    confirmation.show = state.wrapper
  end
  -- Re-registered every save: oil.setup() resets _adapter_by_scheme.
  config._adapter_by_scheme[SCHEME] = {
    name = "oil-download",
    render_action = function(action) return "DOWNLOAD " .. action.label end,
  }
end

--- Queue `batch` to be shown in the dialog oil is about to open for this save.
--- Returns false (and queues nothing) if oil's internals aren't usable.
---@param batch oil_download.Batch
---@return boolean
function M.queue(batch)
  local confirmation, config = internals()
  if not confirmation then return false end
  install(confirmation, config)
  pending = batch
  return true
end

--- Whether oil is still busy with a save: mutating, or re-rendering a buffer
--- afterwards (which would overwrite lines put back too early).
---@return boolean
local function oil_busy()
  local ok, mutator = pcall(require, "oil.mutator")
  if ok and type(mutator.is_mutating) == "function" and mutator.is_mutating() then return true end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].oil_rendering then return true end
  end
  return false
end

--- Run `fn` once oil has finished the save in progress (including waiting on
--- its dialog and re-rendering afterwards). Gives up waiting after a while
--- (a stuck render flag) once no dialog is open, and runs `fn` anyway.
---@param fn fun()
function M.after_save(fn)
  local deadline = vim.uv.now() + 5000
  local function check()
    local dialog_open = vim.bo.filetype == "oil_preview"
    if oil_busy() and (dialog_open or vim.uv.now() < deadline) then
      vim.defer_fn(check, 20)
    else
      fn()
    end
  end
  vim.schedule(check)
end

--- Run `fn` once oil has re-rendered `buf`. After a save oil doesn't re-render
--- hidden oil buffers right away: it marks them `b:oil_dirty` and re-renders on
--- their next BufEnter, which would wipe lines put back before then.
---@param buf integer
---@param fn fun()
function M.when_shown(buf, fn)
  if not (vim.api.nvim_buf_is_valid(buf) and vim.b[buf].oil_dirty) then return fn() end
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    once = true,
    -- Defined after oil's own BufEnter handler, so it runs after that has
    -- started the render; wait for the render to finish.
    callback = function()
      local function check()
        if vim.api.nvim_buf_is_valid(buf) and (vim.b[buf].oil_dirty or vim.b[buf].oil_rendering) then
          vim.defer_fn(check, 20)
        else
          fn()
        end
      end
      vim.schedule(check)
    end,
  })
end

--- Oil reports parse errors as diagnostics on the buffer it parsed, which had
--- the URL lines removed. Run `put_back` (which re-inserts them), then move
--- each diagnostic down past the URL rows above it so it points at the line
--- oil meant. Diagnostics are read before `put_back`, so this is right
--- whether or not Neovim moves them along with inserted text.
---@param stripped { buf: integer, rows: integer[] }[]
---@param put_back fun()
function M.keep_diagnostics(stripped, put_back)
  local ns = vim.api.nvim_get_namespaces()["Oil"]
  local saved = {}
  for i, s in ipairs(stripped) do
    saved[i] = ns and vim.api.nvim_buf_is_valid(s.buf) and vim.diagnostic.get(s.buf, { namespace = ns }) or {}
  end
  put_back()
  for i, s in ipairs(stripped) do
    if #saved[i] > 0 and vim.api.nvim_buf_is_valid(s.buf) then
      for _, d in ipairs(saved[i]) do
        for _, row in ipairs(s.rows) do
          if row - 1 <= d.lnum then
            d.lnum = d.lnum + 1
            if d.end_lnum then d.end_lnum = d.end_lnum + 1 end
          end
        end
      end
      vim.diagnostic.set(ns, s.buf, saved[i])
    end
  end
end

--- If oil never opened the dialog for the queued batch (e.g. the buffer had
--- a parse error), take it back so the caller can restore its lines.
---@param batch oil_download.Batch
---@return boolean taken
function M.take_back(batch)
  if pending == batch then
    pending = nil
    return true
  end
  return false
end

return M
