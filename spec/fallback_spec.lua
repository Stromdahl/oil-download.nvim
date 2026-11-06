local h = require("helpers")

-- Simulates an oil release that renamed the internals we hook: oil itself
-- keeps working (its mutator holds its own reference to the real module), but
-- the plugin can no longer find `confirmation.show`.
describe("when oil's internals have changed", function()
  local dir, real_confirmation, real_confirm

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

  it("downloads nothing on No and says which URLs were skipped", function()
    h.notes = {}
    save_answering(2)

    assert.are.same({}, h.wait_downloads(dir, 1, 500))
    local said = table.concat(vim.tbl_map(function(n) return n.msg end, h.notes), "\n")
    assert.matches("https://example.com/a.zip", said)
  end)
end)
