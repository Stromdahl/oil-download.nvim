-- Tripwire for oil.nvim upgrades: the oil internals this plugin hooks
-- (lua/oil-download/oil_hook.lua) must still exist and behave as assumed.
-- If this fails after bumping oil, the plugin is in fallback mode for users.
local h = require("helpers")

describe("oil internals the plugin depends on", function()
  before_each(function() h.boot() end)

  it("mutator calls confirmation.show through the module table", function()
    local confirmation = require("oil.mutator.confirmation")
    assert.are.equal("function", type(confirmation.show))
    local path = assert(package.searchpath("oil.mutator", package.path))
    local src = table.concat(vim.fn.readfile(path), "\n")
    assert.matches("confirmation%.show%(", src)
  end)

  it("looks up adapters in config._adapter_by_scheme, keyed by scheme", function()
    local config = require("oil.config")
    assert.are.equal("table", type(config._adapter_by_scheme))
    local fake = { name = "probe" }
    config._adapter_by_scheme["oil-download-probe://"] = fake
    assert.are.equal(fake, config.get_adapter_by_scheme("oil-download-probe://x"))
    config._adapter_by_scheme["oil-download-probe://"] = nil
  end)

  it("renders each action in show(actions, should_confirm, cb) via its adapter's render_action", function()
    local config = require("oil.config")
    config._adapter_by_scheme["oil-download-probe://"] = {
      name = "probe",
      render_action = function(action) return "PROBE " .. action.label end,
    }
    h.open(h.tmpdir())
    local oil_buf = vim.api.nvim_get_current_buf()
    local answer
    local action = { type = "download", url = "oil-download-probe://x", label = "https://example.com/a" }

    require("oil.mutator.confirmation").show({ action }, true, function(proceed) answer = proceed end)
    assert.is_true(vim.wait(3000, function() return vim.bo.filetype == "oil_preview" end, 10))
    local dialog = h.lines()
    vim.api.nvim_feedkeys("n", "x", false)
    vim.wait(3000, function() return answer ~= nil end, 10)

    config._adapter_by_scheme["oil-download-probe://"] = nil
    assert.are.equal("PROBE https://example.com/a", dialog[1])
    assert.is_false(answer)
    assert.are.equal(oil_buf, vim.api.nvim_get_current_buf())
    h.reset()
  end)

  it("fires BufWritePre on oil buffers before parsing them", function()
    local seen
    local id = vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "oil://*",
      callback = function() seen = true end,
    })
    h.open(h.tmpdir())
    vim.cmd("w")
    vim.api.nvim_del_autocmd(id)
    h.reset()
    assert.is_true(seen)
  end)

  it("plugin reports the hook as available", function()
    assert.is_true((require("oil-download.oil_hook").available()))
  end)
end)
