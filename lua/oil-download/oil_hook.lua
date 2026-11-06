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
    ---@type oil_download.HookState
    local state = { original = confirmation.show }
    -- Dispatch through package.loaded so a reloaded module takes over.
    state.wrapper = function(...) return require("oil-download.oil_hook")._show(state.original, ...) end
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
