local h = require("helpers")

describe("configuration", function()
  local dir

  after_each(function()
    vim.g.oil_download = nil
    h.reset()
  end)

  before_each(function()
    h.boot()
    dir = h.tmpdir()
    h.open(dir)
  end)

  local function errors()
    return vim.tbl_filter(function(n) return n.level == vim.log.levels.ERROR end, h.notes)
  end

  it("reports an invalid option once and keeps working with its default", function()
    vim.g.oil_download = { downloader = h.recorder, url_pattern = 5 }
    h.notes = {}

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/a" })
    h.write_and_answer("y")
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "https://example.com/b" })
    h.write_and_answer("y")

    assert.are.same({ "https://example.com/a", "https://example.com/b" }, h.wait_downloads(dir, 2))
    assert.are.equal(1, #errors())
    assert.matches("url_pattern", errors()[1].msg)
  end)

  it("setup() keeps a function-valued vim.g.oil_download live", function()
    local downloader = function() return { "false" } end
    vim.g.oil_download = function() return { downloader = downloader } end
    require("oil-download").setup({ default_keymaps = true })

    downloader = h.recorder
    vim.cmd("OilDownload https://example.com/a")

    assert.are.same({ "https://example.com/a" }, h.wait_downloads(dir, 1))
  end)

  it("setup() copes with a vim.g.oil_download function that returns a non-table", function()
    vim.g.oil_download = function() return 5 end
    require("oil-download").setup({ downloader = h.recorder })

    vim.cmd("OilDownload https://example.com/a")

    assert.are.same({ "https://example.com/a" }, h.wait_downloads(dir, 1))
  end)
end)
