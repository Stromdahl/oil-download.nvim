local h = require("helpers")

describe("the dialog hook", function()
  local dir, confirmation

  before_each(function()
    h.boot()
    vim.g.oil_download = { downloader = h.recorder }
    dir = h.tmpdir()
    confirmation = require("oil.mutator.confirmation")
    h.open(dir)
  end)

  -- No restoring confirmation.show afterwards: a foreign wrapper left in
  -- the chain is exactly what the plugin has to live with.
  after_each(h.reset)

  local function save_url_and_answer_yes(url)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { url })
    return h.write_and_answer("y")
  end

  it("still works when another plugin wraps oil's dialog after it", function()
    save_url_and_answer_yes("https://example.com/a") -- installs our wrapper
    local ours = confirmation.show
    confirmation.show = function(...) return ours(...) end

    h.open(dir)
    local dialog = save_url_and_answer_yes("https://example.com/b")

    assert.are.equal("DOWNLOAD https://example.com/b", dialog[1])
    assert.are.same({ "https://example.com/a", "https://example.com/b" }, h.wait_downloads(dir, 2))
  end)

  it("doesn't wrap oil's dialog again when the plugin is reloaded", function()
    save_url_and_answer_yes("https://example.com/a")
    local wrapped = confirmation.show

    package.loaded["oil-download.oil_hook"] = nil
    package.loaded["oil-download"] = nil
    h.open(dir)
    local dialog = save_url_and_answer_yes("https://example.com/b")

    assert.are.equal(wrapped, confirmation.show)
    assert.are.equal("DOWNLOAD https://example.com/b", dialog[1])
    assert.are.same({ "https://example.com/a", "https://example.com/b" }, h.wait_downloads(dir, 2))
  end)
end)
