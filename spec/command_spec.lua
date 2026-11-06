local h = require("helpers")

describe(":OilDownload", function()
  local dir, real_input, real_cwd

  after_each(function()
    vim.ui.input = real_input
    vim.fn.chdir(real_cwd)
    h.reset()
  end)

  before_each(function()
    h.boot()
    vim.g.oil_download = { downloader = h.recorder }
    real_input = vim.ui.input
    real_cwd = vim.fn.getcwd()
    dir = h.tmpdir()
    h.open(dir)
  end)

  it("downloads the given URL into the directory oil is showing", function()
    vim.cmd("OilDownload https://example.com/a.zip")

    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(dir, 1))
  end)

  it("without an argument, asks for the URL prefilled from the clipboard", function()
    vim.fn.setreg("+", "https://example.com/clip.zip")
    local default
    vim.ui.input = function(opts, cb)
      default = opts.default
      cb(opts.default)
    end

    vim.cmd("OilDownload")

    assert.are.equal("https://example.com/clip.zip", default)
    assert.are.same({ "https://example.com/clip.zip" }, h.wait_downloads(dir, 1))
  end)

  it("downloads nothing when the prompt is cancelled", function()
    vim.ui.input = function(_, cb) cb(nil) end

    vim.cmd("OilDownload")

    assert.are.same({}, h.wait_downloads(dir, 1, 300))
  end)

  it("outside oil, downloads into the working directory", function()
    local cwd = h.tmpdir()
    vim.cmd("enew")
    vim.cmd.cd(cwd)

    vim.cmd("OilDownload https://example.com/a.zip")

    assert.are.same({ "https://example.com/a.zip" }, h.wait_downloads(cwd, 1))
  end)
end)
