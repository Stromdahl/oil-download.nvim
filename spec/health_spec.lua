local h = require("helpers")

--- Run :checkhealth oil-download and return the report text.
local function checkhealth()
  vim.cmd("checkhealth oil-download")
  -- Newer Neovim fills the report asynchronously, then sets nomodifiable.
  if vim.fn.has("nvim-0.12") == 1 then vim.wait(5000, function() return not vim.bo.modifiable end, 10) end
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")
  return text
end

describe(":checkhealth oil-download", function()
  after_each(function()
    vim.g.oil_download = nil
    h.reset()
  end)

  before_each(function() h.boot() end)

  it("is OK when the downloader exists and oil's hook points are present", function()
    vim.g.oil_download = { downloader = function(url, dir) return { "sh", url, dir } end }

    local report = checkhealth()

    assert.matches("OK.-sh", report)
    assert.matches("OK.-hook", report)
    assert.not_matches("ERROR", report)
  end)

  it("errors when the downloader is not installed", function()
    vim.g.oil_download = { downloader = function() return { "no-such-downloader-xyz" } end }

    assert.matches("ERROR.-no%-such%-downloader%-xyz", checkhealth())
  end)

  it("warns about fallback mode when oil's internals are missing", function()
    require("oil.mutator")
    local real = package.loaded["oil.mutator.confirmation"]
    package.loaded["oil.mutator.confirmation"] = {}
    local report = checkhealth()
    package.loaded["oil.mutator.confirmation"] = real

    assert.matches("WARNING.-fallback", report)
  end)

  it("flags unknown config keys", function()
    vim.g.oil_download = { defualt_keymaps = false }

    assert.matches("WARNING.-defualt_keymaps", checkhealth())
  end)

  it("confirms the DOWNLOAD highlighting for oil's dialog is on the runtimepath", function()
    assert.matches("OK.-after/syntax/oil_preview%.vim", checkhealth())
  end)
end)
