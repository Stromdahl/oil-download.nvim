local h = require("helpers")

-- Simulates an oil release that renamed the internals we hook: oil itself
-- keeps working (its mutator holds its own reference to the real module), but
-- the plugin can no longer find `confirmation.show`.
describe("when oil's internals have changed", function()
  local dir, real_confirmation, real_confirm

  after_each(function() h.reset() end)

  before_each(function()
    h.boot()
    vim.g.oil_download = { downloader = h.recorder }
    dir = h.tmpdir()
    h.open(dir)
    require("oil.mutator") -- load it first, so it captures the real module
    real_confirmation = package.loaded["oil.mutator.confirmation"]
    package.loaded["oil.mutator.confirmation"] = {}
    real_confirm = vim.fn.confirm
  end)

  after_each(function()
    package.loaded["oil.mutator.confirmation"] = real_confirmation
    vim.fn.confirm = real_confirm
  end)

  local function save_answering(choice)
    local asked
    vim.fn.confirm = function(msg)
      asked = msg
      return choice
    end
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip" })
    vim.cmd("w")
    vim.wait(300)
    return asked
  end

  it("asks with its own prompt and downloads on Yes", function()
    local asked = save_answering(1)

    assert.matches("https://example.com/a.zip", asked)
    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(dir, 1))
  end)

  it("downloads nothing on No and puts the URL lines back", function()
    save_answering(2)

    assert.are.same({}, h.wait_downloads(dir, 1, 500))
    assert.is_true(vim.tbl_contains(h.lines(), "https://example.com/a.zip"))
    assert.is_true(vim.bo.modified)
  end)

  it("puts the URL lines back on No after oil saves the rest of the buffer", function()
    vim.fn.confirm = function() return 2 end
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip", "newfile.txt" })

    h.write_and_answer("y") -- oil's own dialog, for the CREATE

    assert.are.same({ "newfile.txt" }, h.files(dir))
    assert.is_true(vim.wait(1000, function() return vim.tbl_contains(h.lines(), "https://example.com/a.zip") end))
    assert.are.same({}, h.wait_downloads(dir, 1, 300))
  end)

  it("names each URL's own directory when several oil buffers are saved", function()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a.zip" })
    local other = h.tmpdir()
    h.open(other, { keep = true })

    local asked = save_answering(1)

    assert.matches(vim.pesc(dir) .. "%s+https://example%.com/a%.zip", asked)
    assert.matches(vim.pesc(other) .. "%s+https://example%.com/a%.zip", asked)
    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(dir, 1))
    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(other, 1))
  end)

  it("on No after a parse error, keeps oil's diagnostic on the line it flagged", function()
    vim.fn.writefile({}, dir .. "a.txt")
    vim.fn.writefile({}, dir .. "b.txt")
    h.open(dir)
    local entries = h.lines()
    local dup = entries[1]:gsub("a%.txt$", "same.txt")
    local dup2 = entries[2]:gsub("b%.txt$", "same.txt")
    vim.fn.confirm = function() return 2 end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "https://example.com/a", dup, dup2 })

    vim.cmd("w")
    vim.wait(1000, function() return #h.lines() == 3 end)

    assert.are.same({ "https://example.com/a", dup, dup2 }, h.lines())
    local diags = vim.diagnostic.get(0)
    assert.are.equal(1, #diags)
    assert.are.equal(2, diags[1].lnum) -- oil flags the second same.txt
  end)
end)
